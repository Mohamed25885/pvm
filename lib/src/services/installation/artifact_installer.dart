import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/console.dart';
import '../../core/constants.dart';
import '../../core/php_layout.dart';
import '../../core/platform_info.dart';
import '../../domain/exceptions/probe_exception.dart';
import '../../domain/install_record.dart';
import '../../domain/php_release.dart';
import '../../domain/php_version.dart';
import '../../interfaces/i_installer.dart';
import '../folder_probe.dart';
import '../https_get.dart';

/// The transactional install pipeline shared by every release source
/// (roadmap 2.6):
///
/// download to a private temp dir → verify SHA-256 → extract into
/// `versions/.staging-<X.Y>-<pid>` → check the PHP binary ([PhpLayout]) →
/// probe it ([FolderProbe], when given) → write `.pvm-install.json` → atomically rename to the slot `versions/<X.Y>`.
/// The record keeps the full patch.
///
/// Any failure leaves the versions directory exactly as it was.
class ArtifactInstaller {
  final String versionsPath;
  final PhpLayout layout;

  /// Decides whether unpacked binaries need `chmod` (not on Windows).
  final PlatformInfo platform;
  final List<String> allowedHosts;

  /// Fills the record from the staged `php` itself. A failed probe aborts a
  /// [SlotKind.static] install; other kinds warn and keep release metadata.
  final FolderProbe? probe;
  final Console _console;
  final http.Client _client;
  final Duration _retryDelay;

  ArtifactInstaller({
    required this.versionsPath,
    required this.layout,
    required this.platform,
    required this.allowedHosts,
    required this._console,
    this.probe,
    http.Client? client,
    this._retryDelay = const Duration(seconds: 1),
  }) : _client = client ?? http.Client();

  /// Whether the slot of [version] (`versions/<X.Y>`) holds a PHP binary.
  Future<bool> isInstalled(String version) => File(
    layout.phpExecutable(p.join(versionsPath, PhpVersion.parse(version).slot)),
  ).exists();

  /// Whether the slot of [version] already holds exactly [version]. Throws
  /// [SlotFilledException] when it holds another (recorded) patch.
  Future<bool> slotHolds(String version) async {
    if (!await isInstalled(version)) return false;
    final slot = PhpVersion.parse(version).slot;
    String? installed;
    try {
      installed = (await InstallRecord.readFrom(
        p.join(versionsPath, slot),
      ))?.version;
    } catch (_) {
      // Unreadable record: patch unknown, as for a hand-copied slot.
    }
    if (installed != null && installed != version) {
      throw SlotFilledException(slot, installed);
    }
    return true;
  }

  /// Install [release] into its slot `versions/<X.Y>`, replacing any existing
  /// tree.
  ///
  /// A release without a published checksum is only installed when
  /// [allowUnverified] is true; its actual hash is still recorded.
  Future<void> install(
    PhpRelease release,
    String version, {
    required SlotKind kind,
    required bool allowUnverified,
  }) async {
    // [version] becomes a directory name: guard every caller (path traversal).
    final slot = PhpVersion.parse(version).slot;
    final verified = release.sha256.trim().isNotEmpty;
    if (!verified && !allowUnverified) {
      throw UnverifiedReleaseException(version);
    }
    final urlPath = Uri.parse(release.downloadUrl).path.toLowerCase();
    final Future<void> Function(String, String) extract;
    if (urlPath.endsWith('.zip')) {
      extract = extractZip;
    } else if (urlPath.endsWith('.tar.gz') || urlPath.endsWith('.tgz')) {
      extract = extractTarGz;
    } else {
      throw Exception('Unsupported archive type: ${release.downloadUrl}');
    }

    final staging = await stagingFor(slot);
    final tempDir = await Directory.systemTemp.createTemp('pvm-download-');
    try {
      _console.print('Downloading PHP $version...');
      final archive = await download(release, tempDir.path);

      final actualSha = await sha256Of(archive);
      if (verified) {
        _console.print('Verifying SHA256...');
        if (!await verifySha256(archive, release.sha256)) {
          throw Exception('SHA256 verification failed');
        }
      } else {
        _console.printWarning(
          'No published checksum for PHP $version; installing '
          'unverified (sha256 $actualSha recorded).',
        );
      }

      _console.print('Extracting...');
      await staging.create(recursive: true);
      await extract(archive.path, staging.path);

      await commit(
        staging.path,
        release,
        version,
        kind: kind,
        archiveSha256: actualSha,
        verified: verified,
      );
    } finally {
      await _deleteQuietly(staging);
      await _deleteQuietly(tempDir);
    }
  }

  /// The empty staging dir `versions/.staging-<slot>-<pid>` (not created),
  /// after removing leftovers of killed installs of [slot] (any pid). The
  /// caller deletes it when done.
  Future<Directory> stagingFor(String slot) async {
    await Directory(versionsPath).create(recursive: true);
    await for (final e in Directory(versionsPath).list()) {
      if (e is Directory && p.basename(e.path).startsWith('.staging-$slot-')) {
        await _deleteQuietly(e);
      }
    }
    return Directory(p.join(versionsPath, '.staging-$slot-$pid'));
  }

  /// Check the PHP binary in [tree] (a dir inside `versions/`), probe it,
  /// write `.pvm-install.json` and atomically move [tree] to the slot of
  /// [version]. The old slot survives any failure.
  Future<void> commit(
    String tree,
    PhpRelease release,
    String version, {
    required SlotKind kind,
    required String archiveSha256,
    required bool verified,
  }) async {
    final binary = layout.phpExecutable(tree);
    if (!await File(binary).exists()) {
      throw Exception(
        'Archive does not contain ${p.relative(binary, from: tree)}',
      );
    }

    final target = p.join(versionsPath, PhpVersion.parse(version).slot);
    ProbeResult? probed;
    try {
      probed = await probe?.probe(tree);
    } on ProbeException catch (e) {
      // A static or source slot is only useful with what the probe reports.
      if (kind == SlotKind.static || kind == SlotKind.source) rethrow;
      _console.printWarning('Could not probe PHP $version: ${e.message}');
    }
    // Probe paths point into staging; the record must name the slot.
    String? moved(String? path) =>
        path != null && (p.isWithin(tree, path) || p.equals(tree, path))
        ? p.normalize(p.join(target, p.relative(path, from: tree)))
        : path;

    await InstallRecord(
      version: version,
      sourceUrl: release.downloadUrl,
      archiveSha256: archiveSha256,
      verified: verified,
      kind: kind,
      installedAt: DateTime.now().toUtc(),
      files: await InstallRecord.hashTree(tree),
      zts: probed?.zts ?? release.buildType == BuildType.ts,
      arch: probed?.arch ?? release.architecture.name,
      apiNo: probed?.apiNo ?? '',
      phpConfig: moved(probed?.phpConfig),
      prefix: moved(probed?.prefix),
      extensionDir: moved(probed?.extensionDir) ?? '',
      writable: probed?.writable ?? true,
      vsVersion: probed?.vsVersion,
    ).writeTo(tree);

    await _commit(Directory(tree), Directory(target));
  }

  Future<String> sha256Of(File file) async =>
      crypto.sha256.convert(await file.readAsBytes()).toString();

  Future<bool> verifySha256(File file, String expectedHash) async {
    if (expectedHash.trim().isEmpty) return false;
    return (await sha256Of(file)) == expectedHash.trim().toLowerCase();
  }

  /// Atomically replace [target] with [staging]; on failure the previous
  /// installation (if any) is restored.
  Future<void> _commit(Directory staging, Directory target) async {
    Directory? backup;
    if (await target.exists()) {
      backup = await target.rename('${target.path}.old-$pid');
    }
    try {
      await staging.rename(target.path);
    } catch (_) {
      if (backup != null) await backup.rename(target.path);
      rethrow;
    }
    if (backup != null) await _deleteQuietly(backup);
  }

  Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Best effort: leftovers are named .staging-/.old- and ignored by PVM.
    }
  }

  /// Extracts [zipPath] into [destPath], aborting on any entry that would
  /// land outside [destPath] (zip-slip) or that is a symbolic link.
  Future<void> extractZip(String zipPath, String destPath) async => _extract(
    ZipDecoder().decodeBytes(await File(zipPath).readAsBytes()),
    destPath,
  );

  /// Extracts the `.tar.gz` at [tgzPath] into [destPath] with the same guards
  /// as [extractZip] (hard links are rejected too). A lone top-level `php`
  /// (static-php builds) is placed at `bin/php` and made executable.
  Future<void> extractTarGz(String tgzPath, String destPath) async {
    final archive = TarDecoder().decodeBytes(
      GZipDecoder().decodeBytes(await File(tgzPath).readAsBytes()),
    );
    final entries = archive.files.where((f) => f.name.isNotEmpty).toList();
    if (entries.length == 1 &&
        entries.single.isFile &&
        !entries.single.isSymbolicLink &&
        p.posix.normalize(entries.single.name) == 'php') {
      final php = File(layout.phpExecutable(destPath));
      await php.parent.create(recursive: true);
      await php.writeAsBytes(entries.single.content);
      if (platform.osType != 'windows') {
        final r = await Process.run('chmod', ['0755', php.path]);
        if (r.exitCode != 0) throw Exception('chmod failed: ${r.stderr}');
      }
      return;
    }
    await _extract(archive, destPath);
  }

  Future<void> _extract(Archive archive, String destPath) async {
    final dest = p.normalize(p.absolute(destPath));

    for (final file in archive.files) {
      final name = file.name.replaceAll('\\', '/');
      if (name.isEmpty) continue;
      if (p.isAbsolute(name) ||
          p.posix.isAbsolute(name) ||
          name.contains(':') ||
          file.isSymbolicLink ||
          file.isHardLink) {
        throw Exception('Unsafe archive entry rejected: ${file.name}');
      }
      final outPath = p.normalize(p.join(dest, name));
      if (!p.isWithin(dest, outPath)) {
        throw Exception('Unsafe archive entry rejected: ${file.name}');
      }

      if (name.endsWith('/') || !file.isFile) {
        await Directory(outPath).create(recursive: true);
      } else {
        await Directory(p.dirname(outPath)).create(recursive: true);
        await File(outPath).writeAsBytes(file.content);
      }
    }
  }

  /// Download [release] into [destDir] with retries. Only `https` URLs on
  /// [allowedHosts] (or their subdomains) are accepted (S7).
  Future<File> download(
    PhpRelease release,
    String destDir, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    _validateUrl(release.downloadUrl);

    final fileName = p.url.basename(Uri.parse(release.downloadUrl).path);
    final destPath = p.join(destDir, fileName);
    final partFile = File('$destPath.part');

    await Directory(destDir).create(recursive: true);

    for (var attempt = 0; attempt < PvmTimeouts.downloadMaxRetries; attempt++) {
      IOSink? sink;
      try {
        var downloadedBytes = 0;
        final response = await httpsGet(
          _client,
          Uri.parse(release.downloadUrl),
        ).timeout(Duration(seconds: PvmTimeouts.downloadTimeoutSeconds));

        if (response.statusCode != 200) {
          throw DownloadException(
            'Failed to download: HTTP ${response.statusCode}',
          );
        }

        final totalBytes = response.contentLength ?? 0;
        sink = partFile.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            onProgress(
              DownloadProgress(
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                percentComplete: downloadedBytes / totalBytes,
              ),
            );
          }
        }

        await sink.close();
        sink = null;
        final destFile = File(destPath);
        if (await destFile.exists()) await destFile.delete();
        return await partFile.rename(destPath);
      } catch (e) {
        try {
          await sink?.close();
        } catch (_) {}
        if (await partFile.exists()) await partFile.delete();
        if (attempt == PvmTimeouts.downloadMaxRetries - 1) rethrow;
        await Future<void>.delayed(_retryDelay * (attempt + 1));
      }
    }
    throw DownloadException('Download failed'); // unreachable
  }

  void _validateUrl(String url) {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();
    final hostAllowed = allowedHosts.any(
      (d) => host == d || host.endsWith('.$d'),
    );
    if (uri.scheme != 'https' || !hostAllowed) {
      throw DownloadException(
        'Download from $url not allowed. Allowed: '
        'https://${allowedHosts.join(", https://")}',
      );
    }
  }

  void dispose() => _client.close();
}
