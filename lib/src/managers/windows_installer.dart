import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../domain/php_release.dart';
import '../interfaces/i_installer.dart';

/// Windows installer - downloads ZIP and extracts to versions directory.
class WindowsInstaller implements IInstaller {
  static const int _downloadTimeout = 300;
  static const int _maxRetries = 3;

  final String _versionsPath;
  final String downloadBaseUrl;
  late final http.Client _client;

  WindowsInstaller({
    required String versionsPath,
    this.downloadBaseUrl = 'https://windows.php.net/downloads/releases/',
  }) : _versionsPath = versionsPath {
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
  Future<void> install(String version) async {
    // Check if already installed
    if (await isInstalled(version)) {
      return;
    }

    final versionDir = p.join(versionsPath, version);

    // Create directory for PHP version
    await Directory(versionDir).create(recursive: true);

    // Note: Actual download from windows.php.net should be implemented
    // using IReleaseSource to get the download URL
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

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final request = http.Request('GET', Uri.parse(release.downloadUrl));
        final response = await _client.send(request).timeout(
              Duration(seconds: _downloadTimeout),
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
        if (attempt == _maxRetries - 1) {
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
