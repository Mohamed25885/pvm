import '../domain/php_version.dart';
import '../interfaces/i_installer.dart';
import '../core/process_manager.dart';
import 'package_manager_installer.dart';

/// macOS installer - uses Homebrew.
class MacOSInstaller extends PackageManagerInstaller {
  final bool useSudo;

  MacOSInstaller({
    required String versionsPath,
    required IProcessManager processManager,
    this.useSudo = false,
  }) : super(versionsPath: versionsPath, processManager: processManager);

  @override
  String get installationType => 'package manager (brew)';

  @override
  Future<void> install(String version, {InstallOptions? options}) async {
    // Security validation against injection
    final phpVersion = PhpVersion.parse(version);
    final force = options?.force ?? false;
    if (!force && await isInstalled(phpVersion.toString())) {
      return;
    }

    // Normalize version for brew (e.g., "8.4" -> "php@8.4")
    final brewPackage = _normalizeBrewPackage(phpVersion.toShortString());

    final args = ['install', brewPackage];
    // Note: brew doesn't need sudo
    final result = await processManager.runCaptured(
      ProcessSpec(executable: 'brew', arguments: args),
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to install $brewPackage: ${result.stderr}');
    }
  }

  String _normalizeBrewPackage(String version) {
    // Convert "8.4" to "php@8.4" for brew
    return 'php@${version.split('.').take(2).join('.')}';
  }
}
