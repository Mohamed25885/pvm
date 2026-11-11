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

  /// The HTTP status of a non-200 response, when that was the failure.
  final int? statusCode;
  const DownloadException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Options for installation
class InstallOptions {
  final Architecture? architecture;
  final BuildType? buildType;
  final bool force;

  /// Permit installing a build that has no published SHA-256 (archived
  /// patch releases on windows.php.net). TLS is then the only protection.
  final bool allowUnverified;

  /// `pvm update`: the install may replace another patch of the slot, and
  /// this runs on the staged slot (record written) just before the swap. A
  /// throw aborts the update and leaves the old slot as it was.
  final Future<void> Function(String staged)? update;

  const InstallOptions({
    this.architecture,
    this.buildType,
    this.force = false,
    this.allowUnverified = false,
    this.update,
  });
}

/// Outcome of [IInstaller.install].
class InstallResult {
  /// The concrete version (e.g. `8.3.14`) that is now installed.
  final String version;

  /// True when the version was already present and nothing was changed.
  final bool alreadyInstalled;

  const InstallResult(this.version, {this.alreadyInstalled = false});
}

/// Thrown when no build matches the requested version/arch/build type.
class NoMatchingReleaseException implements Exception {
  final String message;
  const NoMatchingReleaseException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a matching build exists but cannot be verified and the user
/// did not pass `--allow-unverified`.
class UnverifiedReleaseException implements Exception {
  final String version;
  const UnverifiedReleaseException(this.version);

  @override
  String toString() =>
      'PHP $version is an archived build with no published SHA-256 checksum.\n'
      'Re-run with --allow-unverified to install it anyway (TLS-only protection).';
}

/// Thrown when the slot `versions/<X.Y>` already holds another patch: a slot
/// keeps one patch, and `pvm update` is how it changes.
class SlotFilledException implements Exception {
  final String slot;
  final String installed;
  const SlotFilledException(this.slot, this.installed);

  @override
  String toString() => '$slot is installed ($installed). Run: pvm update $slot';
}

/// Thrown when the old slot cannot be moved aside for the swap: on Windows,
/// a running PHP or web server holds its files.
class SlotInUseException implements Exception {
  final String slot;
  const SlotInUseException(this.slot);

  @override
  String toString() =>
      'PHP $slot is in use (a running php.exe or web server holds its '
      'files). Stop it, then run: pvm update $slot';
}

/// Thrown when the swap failed after the old slot was moved to [backup] and
/// moving it back failed too: the slot is gone until the user renames it.
class SlotRestoreException implements Exception {
  final String slot;
  final String backup;
  final String target;

  /// The error that failed the swap.
  final Object cause;

  const SlotRestoreException(this.slot, this.backup, this.target, this.cause);

  @override
  String toString() =>
      'PHP $slot was moved to $backup and could not be put back; '
      'rename it to $target yourself';
}

/// Installer interface for PHP installation across platforms.
///
/// Windows: windows.php.net ZIPs. Linux/macOS: static-php.dev builds.
abstract class IInstaller {
  /// The base directory where PHP versions are installed.
  String get versionsPath;

  /// Install a PHP version.
  /// [version] - the PHP version to install (e.g., "8.4", "8.4.1")
  Future<InstallResult> install(String version, {InstallOptions? options});

  /// Check if a version is installed.
  Future<bool> isInstalled(String version);

  /// Get the installation type description.
  /// Returns: "ZIP extraction" or "static-php build"
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
