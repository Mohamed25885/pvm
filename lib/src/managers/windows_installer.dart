import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/console.dart';
import '../domain/php_release.dart';
import '../domain/php_version.dart';
import '../interfaces/i_installer.dart';
import '../core/constants.dart';
import '../services/release_fetcher.dart';

/// Windows installer - downloads ZIP and extracts to versions directory.
///
/// Installs are transactional: the ZIP is downloaded to a private temp
/// directory, verified, extracted into `versions/.staging-<v>`, checked for
/// `php.exe`, and only then moved to `versions/<v>`. Any failure leaves the
/// versions directory exactly as it was.
class WindowsInstaller implements IInstaller {
  final String _versionsPath;
  final String downloadBaseUrl;
  final IReleaseFetcher _fetcher;
  final Console _console;
  final http.Client _client;

  WindowsInstaller({
    required String versionsPath,
    required IReleaseFetcher releaseFetcher,
    required Console console,
    this.downloadBaseUrl = PvmUrls.windowsDownloadBase,
    http.Client? client,
    Duration retryDelay = const Duration(seconds: 1),
  }) : _versionsPath = versionsPath,
       _fetcher = releaseFetcher,
       _console = console,
       _client = client ?? http.Client(),
       _retryDelay = retryDelay;

  final Duration _retryDelay;

  static const List<String> allowedDomains = [
    'windows.php.net',
    'downloads.php.net',
  ];

  @override
  String get versionsPath => _versionsPath;

  @override
  String get installationType => 'ZIP extraction';

  @override
  Future<bool> isInstalled(String version) async {
    final versionDir = p.join(versionsPath, version);
    final phpExe = p.join(versionDir, PvmConstants.phpExecutable);
    return File(phpExe).exists();
  }

  @override
  Future<void> install(String version, {InstallOptions? options}) async {
    // Validate before the value is used in any path (path traversal guard).
    final phpVersion = PhpVersion.parse(version);
    final force = options?.force ?? false;

    _console.print('Fetching available PHP versions...');
    final releases = await _fetcher.fetchReleases();

    final arch = options?.architecture ?? Architecture.x64;
    final buildType = options?.buildType ?? BuildType.nts;

    final filter = PhpReleaseFilter(
      major: phpVersion.major,
      minor: phpVersion.minor,
      patch: phpVersion.patch,
      architecture: arch,
      buildType: buildType,
    );

    final matching = releases.where((r) => filter.matches(r)).toList();

    if (matching.isEmpty) {
      _console.printError(
        'No matching PHP release found for $version ($arch, $buildType)',
      );
      throw Exception('No matching PHP release found');
    }

    final release = matching.first;
    final displayVersion = release.displayVersion;
    // Re-validate: the version string came from remote JSON.
    PhpVersion.parse(displayVersion);
    final targetDir = p.join(versionsPath, displayVersion);

    if (!force && await isInstalled(displayVersion)) {
      _console.printError(
        'PHP $displayVersion already installed. Use --force to reinstall',
      );
      return;
    }

    await preInstall(displayVersion);
    await Directory(versionsPath).create(recursive: true);

    final tempDir = await Directory.systemTemp.createTemp('pvm-download-');
    final staging = Directory(
      p.join(versionsPath, '.staging-$displayVersion-$pid'),
    );
    try {
      _console.print('Downloading PHP $displayVersion...');
      final zipFile = await downloadPhp(release, tempDir.path);

      _console.print('Verifying SHA256...');
      if (!await verifySha256(zipFile, release.sha256)) {
        throw Exception('SHA256 verification failed');
      }

      _console.print('Extracting...');
      if (await staging.exists()) await staging.delete(recursive: true);
      await staging.create(recursive: true);
      await extractZip(zipFile.path, staging.path);

      if (!await File(
        p.join(staging.path, PvmConstants.phpExecutable),
      ).exists()) {
        throw Exception(
          'Archive does not contain ${PvmConstants.phpExecutable}',
        );
      }

      await _commit(staging, Directory(targetDir));
    } on Exception catch (e) {
      await onInstallFailed(displayVersion, e);
      rethrow;
    } finally {
      await _deleteQuietly(staging);
      await _deleteQuietly(tempDir);
    }

    await postInstall(displayVersion);
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
  Future<void> extractZip(String zipPath, String destPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dest = p.normalize(p.absolute(destPath));

    for (final file in archive.files) {
      final name = file.name.replaceAll('\\', '/');
      if (name.isEmpty) continue;
      if (p.isAbsolute(name) ||
          p.posix.isAbsolute(name) ||
          name.contains(':') ||
          file.isSymbolicLink) {
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

  @override
  Future<File> downloadPhp(
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
        final request = http.Request('GET', Uri.parse(release.downloadUrl));
        final response = await _client
            .send(request)
            .timeout(Duration(seconds: PvmTimeouts.downloadTimeoutSeconds));

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
    final hostAllowed = allowedDomains.any(
      (d) => host == d || host.endsWith('.$d'),
    );
    if (uri.scheme != 'https' || !hostAllowed) {
      throw DownloadException(
        'Download from $url not allowed. Allowed: https://${allowedDomains.join(", https://")}',
      );
    }
  }

  @override
  Future<bool> verifySha256(File file, String expectedHash) async {
    if (expectedHash.trim().isEmpty) return false;
    final bytes = await file.readAsBytes();
    final hash = crypto.sha256.convert(bytes).toString();
    return hash.toLowerCase() == expectedHash.trim().toLowerCase();
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }

  @override
  Future<void> preInstall(String version) async {}

  @override
  Future<void> onInstalling(String version, double progress) async {}

  @override
  Future<void> postInstall(String version) async {}

  @override
  Future<void> onInstallFailed(String version, Exception error) async {}
}
