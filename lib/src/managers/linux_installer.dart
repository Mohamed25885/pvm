import 'dart:io';

import '../domain/php_release.dart';
import '../interfaces/i_installer.dart';

/// Linux installer - uses apt-get package manager.
class LinuxInstaller implements IInstaller {
  final String _versionsPath;
  final bool useSudo;

  LinuxInstaller({
    required String versionsPath,
    this.useSudo = false,
  }) : _versionsPath = versionsPath;

  @override
  String get versionsPath => _versionsPath;

  @override
  String get installationType => 'package manager (apt)';

  @override
  Future<bool> isInstalled(String version) async {
    // Check if php is available via which
    final result = await Process.run('which', ['php']);
    if (result.exitCode != 0) return false;

    // Get PHP version
    final versionResult = await Process.run('php', ['-r', 'echo PHP_VERSION;']);
    if (versionResult.exitCode != 0) return false;

    final installedVersion = versionResult.stdout.toString().trim();
    // Normalize: "8.4.20" should match "8.4.20"
    return installedVersion.startsWith(version) || installedVersion.startsWith(version.split('.')[0] + '.');
  }

  @override
  Future<void> install(String version) async {
    // Check if already installed
    if (await isInstalled(version)) {
      return;
    }

    // Normalize version for apt (e.g., "8.4" -> "php8.4")
    final aptPackage = _normalizeAptPackage(version);

    // Install using apt-get (with sudo if needed)
    final result = await Process.run(
      useSudo ? 'sudo' : 'apt-get',
      useSudo ? ['apt-get', 'install', '-y', aptPackage] : ['apt-get', 'install', '-y', aptPackage],
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to install $aptPackage: ${result.stderr}');
    }
  }

  @override
  Future<File> downloadPhp(
    PhpRelease release,
    String destDir, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    // Linux uses package manager, no download needed
    throw UnimplementedError(
      'Linux uses package manager (apt), not downloads',
    );
  }

  @override
  Future<bool> verifySha256(File file, String expectedHash) async {
    // Linux uses package manager, no verification needed
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

  String _normalizeAptPackage(String version) {
    // Convert "8.4.20" to "php8.4" for apt
    final parts = version.split('.');
    if (parts.length > 2) parts.removeLast(); // Remove patch
    return 'php${parts.join('.')}';
  }
}
