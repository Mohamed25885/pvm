import 'dart:io';

import '../domain/php_release.dart';
import '../interfaces/i_installer.dart';

/// macOS installer - uses Homebrew.
class MacOSInstaller implements IInstaller {
  final String _versionsPath;
  final bool useSudo;

  MacOSInstaller({
    required String versionsPath,
    this.useSudo = false,
  }) : _versionsPath = versionsPath;

  @override
  String get versionsPath => _versionsPath;

  @override
  String get installationType => 'package manager (brew)';

  @override
  Future<bool> isInstalled(String version) async {
    // Check if php is available via which
    final result = await Process.run('which', ['php']);
    if (result.exitCode != 0) return false;

    // Get PHP version
    final versionResult = await Process.run('php', ['-r', 'echo PHP_VERSION;']);
    if (versionResult.exitCode != 0) return false;

    final installedVersion = versionResult.stdout.toString().trim();
    return installedVersion.startsWith(version) || installedVersion.startsWith(version.split('.')[0] + '.');
  }

  @override
  Future<void> install(String version) async {
    if (await isInstalled(version)) {
      return;
    }

    // Normalize version for brew (e.g., "8.4" -> "php@8.4")
    final brewPackage = _normalizeBrewPackage(version);

    final args = ['install', brewPackage];
    // Note: brew doesn't need sudo
    final result = await Process.run('brew', args);

    if (result.exitCode != 0) {
      throw Exception('Failed to install $brewPackage: ${result.stderr}');
    }
  }

  @override
  Future<File> downloadPhp(
    PhpRelease release,
    String destDir, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    // macOS uses package manager, no download needed
    throw UnimplementedError(
      'macOS uses package manager (brew), not downloads',
    );
  }

  @override
  Future<bool> verifySha256(File file, String expectedHash) async {
    // macOS uses package manager, no verification needed
    return true;
  }

  @override
  Future<void> dispose() async {
    // No resources to clean up
  }

  @override
  Future<void> preInstall(String version) async {}

  @override
  Future<void> onInstalling(String version, double progress) async {}

  @override
  Future<void> postInstall(String version) async {}

  @override
  Future<void> onInstallFailed(String version, Exception error) async {}

  String _normalizeBrewPackage(String version) {
    // Convert "8.4" to "php@8.4" for brew
    return 'php@${version.split('.').take(2).join('.')}';
  }
}
