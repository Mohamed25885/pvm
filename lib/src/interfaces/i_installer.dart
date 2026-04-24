import 'dart:io';
import '../domain/php_release.dart';

/// Progress callback for downloads
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

/// Exception for download errors
class DownloadException implements Exception {
  final String message;
  const DownloadException(this.message);

  @override
  String toString() => message;
}

/// Installer interface for PHP installation across platforms.
///
/// Windows: Downloads ZIP and extracts to versions directory.
/// Linux/Mac: Uses package manager (apt/brew).
abstract class IInstaller {
  /// The base directory where PHP versions are installed.
  String get versionsPath;

  /// Install a PHP version.
  /// [version] - the PHP version to install (e.g., "8.4", "8.4.1")
  Future<void> install(String version);

  /// Check if a version is installed.
  Future<bool> isInstalled(String version);

  /// Get the installation type description.
  /// Returns: "ZIP extraction" or "package manager"
  String get installationType;

  /// Download a release to destination directory
  Future<File> downloadPhp(
    PhpRelease release,
    String destDir, {
    void Function(DownloadProgress)? onProgress,
  });

  /// Verify downloaded file SHA256
  Future<bool> verifySha256(File file, String expectedHash);

  /// Clean up any temporary resources
  Future<void> dispose();

  /// Called before installation starts.
  /// [version] - the PHP version being installed.
  /// Failure aborts installation.
  Future<void> preInstall(String version);

  /// Called during installation for progress reporting.
  /// [version] - the PHP version being installed.
  /// [progress] - value from 0.0 to 1.0 indicating progress.
  /// Failure logs warning but continues installation.
  Future<void> onInstalling(String version, double progress);

  /// Called after successful installation.
  /// [version] - the PHP version that was installed.
  /// Failure logs error but installation is considered successful.
  Future<void> postInstall(String version);

  /// Always called on any installation failure.
  /// [version] - the PHP version that failed to install.
  /// [error] - the exception that caused the failure.
  Future<void> onInstallFailed(String version, Exception error);
}
