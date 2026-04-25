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
class WindowsInstaller implements IInstaller {
  final String _versionsPath;
  final String downloadBaseUrl;
  final IReleaseFetcher _fetcher;
  final Console _console;
  late final http.Client _client;


  WindowsInstaller({
    required String versionsPath,
    required IReleaseFetcher releaseFetcher,
    required Console console,
    this.downloadBaseUrl = PvmUrls.windowsDownloadBase,
  })  : _versionsPath = versionsPath,
        _fetcher = releaseFetcher,
        _console = console {
    _client = http.Client();
  }

  static const List<String> allowedDomains = ['windows.php.net', 'downloads.php.net'];

  @override
  String get versionsPath => _versionsPath;

  @override
  String get installationType => 'ZIP extraction';

  @override
  Future<bool> isInstalled(String version) async {
    final versionDir = p.join(versionsPath, version);
    final phpExe = p.join(versionDir, 'php.exe');
    return File(phpExe).exists();
  }

  @override
  Future<void> install(String version, {InstallOptions? options}) async {
    final force = options?.force ?? false;

    if (!force && await isInstalled(version)) {
      _console.printError('PHP $version already installed. Use --force to reinstall');
      return;
    }

    // Security validation against path traversal
    final phpVersion = PhpVersion.parse(version);

    _console.print('Fetching available PHP versions...');
    final releases = await _fetcher.fetchReleases();

    final major = phpVersion.major;
    final minor = phpVersion.minor;
    final patch = phpVersion.patch;

    final arch = options?.architecture ?? Architecture.x64;
    final buildType = options?.buildType ?? BuildType.nts;

    final filter = PhpReleaseFilter(
      major: major,
      minor: minor,
      patch: patch,
      architecture: arch,
      buildType: buildType,
    );

    final matching = releases.where((r) => filter.matches(r)).toList();

    if (matching.isEmpty) {
      _console.printError('No matching PHP release found for $version ($arch, $buildType)');
      throw Exception('No matching PHP release found');
    }

    final release = matching.first;
    final targetDir = p.join(versionsPath, release.displayVersion);

    if (!force && await Directory(targetDir).exists()) {
      _console.printError('PHP ${release.displayVersion} already installed. Use --force to reinstall');
      return;
    }

    await preInstall(release.displayVersion);
    await Directory(targetDir).create(recursive: true);

    _console.print('Downloading PHP ${release.displayVersion}...');
    final zipFile = await downloadPhp(release, versionsPath);

    _console.print('Verifying SHA256...');
    final valid = await verifySha256(zipFile, release.sha256);
    if (!valid) {
      await zipFile.delete();
      final err = Exception('SHA256 verification failed');
      await onInstallFailed(release.displayVersion, err);
      throw err;
    }

    _console.print('Extracting...');
    await _extractZip(zipFile.path, targetDir);
    await zipFile.delete();

    await postInstall(release.displayVersion);
  }

  Future<void> _extractZip(String zipPath, String destPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final destDir = Directory(p.normalize(destPath));
    final destCanonical = destDir.path;

    for (final file in archive.files) {
      final filename = file.name;
      final fullPath = p.join(destPath, filename);
      final normalizedPath = p.normalize(fullPath);

      if (!normalizedPath.startsWith(destCanonical) && normalizedPath != destCanonical) {
        continue;
      }

      if (filename.endsWith('/')) {
        await Directory(fullPath).create(recursive: true);
      } else {
        await Directory(p.dirname(fullPath)).create(recursive: true);
        await File(fullPath).writeAsBytes(file.content);
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

    final fileName = p.url.basename(release.downloadUrl);
    final destPath = p.join(destDir, fileName);

    // Check if file already exists
    final existingFile = File(destPath);
    if (await existingFile.exists()) {
      return existingFile;
    }

    // Ensure destination directory exists
    final destDirFile = Directory(destDir);
    if (!await destDirFile.exists()) {
      await destDirFile.create(recursive: true);
    }

    int downloadedBytes = 0;
    int totalBytes = 0;

    for (int attempt = 0; attempt < PvmTimeouts.downloadMaxRetries; attempt++) {
      try {
        final request = http.Request('GET', Uri.parse(release.downloadUrl));
        final response = await _client.send(request).timeout(
              Duration(seconds: PvmTimeouts.downloadTimeoutSeconds),
            );

        if (response.statusCode != 200) {
          throw DownloadException(
            'Failed to download: HTTP ${response.statusCode}',
          );
        }

        totalBytes = response.contentLength ?? 0;
        final sink = File(destPath).openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            onProgress(DownloadProgress(
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
              percentComplete: downloadedBytes / totalBytes,
            ));
          }
        }

        await sink.close();
        break;
      } catch (e) {
        if (attempt == PvmTimeouts.downloadMaxRetries - 1) {
          // Clean up partial download
          if (await existingFile.exists()) {
            await existingFile.delete();
          }
          rethrow;
        }
        // Wait before retry
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }

    return File(destPath);
  }

  void _validateUrl(String url) {
    final uri = Uri.parse(url);
    if (!allowedDomains.any((d) => uri.host.endsWith(d))) {
      throw DownloadException(
        'Download from ${uri.host} not allowed. Allowed: ${allowedDomains.join(", ")}',
      );
    }
  }

  @override
  Future<bool> verifySha256(File file, String expectedHash) async {
    final bytes = await file.readAsBytes();
    final hash = crypto.sha256.convert(bytes).toString();
    return hash.toLowerCase() == expectedHash.toLowerCase();
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
