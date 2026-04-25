import '../domain/php_version.dart';
import '../interfaces/i_installer.dart';
import '../core/process_manager.dart';
import 'package_manager_installer.dart';

/// Linux installer - uses apt-get package manager.
class LinuxInstaller extends PackageManagerInstaller {
  final bool useSudo;

  LinuxInstaller({
    required String versionsPath,
    required IProcessManager processManager,
    this.useSudo = false,
  }) : super(versionsPath: versionsPath, processManager: processManager);

  @override
  String get installationType => 'package manager (apt)';

  @override
  Future<void> install(String version, {InstallOptions? options}) async {
    // Security validation against injection
    final phpVersion = PhpVersion.parse(version);
    final force = options?.force ?? false;
    // Check if already installed
    if (!force && await isInstalled(phpVersion.toString())) {
      return;
    }

    // Normalize version for apt (e.g., "8.4" -> "php8.4")
    final aptPackage = _normalizeAptPackage(phpVersion.toShortString());

    // Install using apt-get (with sudo if needed)
    final spec = useSudo
        ? ProcessSpec(
            executable: 'sudo',
            arguments: ['apt-get', 'install', '-y', aptPackage],
          )
        : ProcessSpec(
            executable: 'apt-get',
            arguments: ['install', '-y', aptPackage],
          );

    final result = await processManager.runCaptured(spec);
    if (result.exitCode != 0) {
      throw Exception('Failed to install $aptPackage: ${result.stderr}');
    }
  }

  String _normalizeAptPackage(String version) {
    // Convert "8.4.20" to "php8.4" for apt
    final parts = version.split('.');
    if (parts.length > 2) parts.removeLast(); // Remove patch
    return 'php${parts.join('.')}';
  }
}
