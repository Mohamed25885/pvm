import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../domain/php_release.dart';
import 'release_fetcher.dart';

class DownloadProgress {
  final int downloadedBytes;
  final int totalBytes;
  final double percentComplete;

  const DownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.percentComplete,
  });
}

class PhpDownloaderException implements Exception {
  final String message;
  const PhpDownloaderException(this.message);
  @override
  String toString() => message;
}

class PhpDownloader {
  static const int _downloadTimeout = 300;
  static const int _maxRetries = 3;

  /// Allowed domains for download - can be configured
  /// Default: common PHP download domains
  final List<String> allowedDomains;

  final http.Client _client;

  /// Create with default allowed domains
  PhpDownloader()
      : allowedDomains = ['windows.php.net', 'downloads.php.net'],
        _client = http.Client();

  /// Create with custom allowed domains
  PhpDownloader.withDomains(List<String> domains)
      : allowedDomains = domains,
        _client = http.Client();

  Future<List<PhpRelease>> fetchReleases(IReleaseFetcher fetcher) async {
    return fetcher.fetchReleases();
  }

  Future<File> download(
    PhpRelease release,
    String destDir, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    _validateUrl(release.downloadUrl);

    final fileName = p.url.basename(release.downloadUrl);
    final destPath = p.join(destDir, fileName);
    await Directory(destDir).create(recursive: true);

    int attempts = 0;
    Exception? lastError;

    while (attempts < _maxRetries) {
      attempts++;
      try {
        final response = await _client
            .send(
              http.Request('GET', Uri.parse(release.downloadUrl)),
            )
            .timeout(const Duration(seconds: _downloadTimeout));

        if (response.statusCode != 200) {
          throw PhpDownloaderException(
              'Download failed: HTTP ${response.statusCode}');
        }

        final totalBytes = response.contentLength ?? 0;
        int downloadedBytes = 0;
        final bytes = <int>[];

        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          downloadedBytes += chunk.length;

          if (onProgress != null && totalBytes > 0) {
            onProgress(DownloadProgress(
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
              percentComplete: downloadedBytes / totalBytes,
            ));
          }
        }

        final file = File(destPath);
        await file.writeAsBytes(bytes);

        return file;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempts < _maxRetries) {
          await Future.delayed(Duration(seconds: attempts));
        }
      }
    }

    throw PhpDownloaderException(
        'Download failed after $_maxRetries attempts: $lastError');
  }

  Future<bool> verifySha256(File file, String expectedHash) async {
    if (expectedHash.isEmpty) return true;

    final bytes = await file.readAsBytes();
    final hash = crypto.sha256.convert(bytes).toString();
    return hash.toLowerCase() == expectedHash.toLowerCase();
  }

  void _validateUrl(String url) {
    final isAllowed = allowedDomains.any((d) => url.contains(d));
    if (!isAllowed) {
      throw PhpDownloaderException('URL not allowed: $url');
    }
  }

  void dispose() {
    _client.close();
  }
}
