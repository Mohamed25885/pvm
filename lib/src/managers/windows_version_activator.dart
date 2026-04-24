import 'dart:io';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../interfaces/i_version_activator.dart';

/// Windows version activator - uses mklink for symlinks.
class WindowsVersionActivator implements IVersionActivator {
  final String versionsPath;
  final String homeDirectory;

  WindowsVersionActivator({
    required this.versionsPath,
    required this.homeDirectory,
  });

  @override
  Future<void> activateGlobal(String version) async {
    final targetPath = p.join(versionsPath, version);
    final linkPath = p.join(homeDirectory, '.pvm');

    // Run:mklink /D link target
    final result =
        await Process.run('cmd', ['/c', 'mklink', '/D', linkPath, targetPath]);

    if (result.exitCode != 0) {
      throw Exception('Failed to create global symlink: ${result.stderr}');
    }
  }

  @override
  Future<void> activateLocal(String version) async {
    // Find project root by walking up from current directory
    final projectRoot = await _findProjectRoot();
    final targetPath = p.join(versionsPath, version);
    final linkPath = p.join(projectRoot.path, PvmConstants.pvmDirName);

    // Run: mklink /D link target
    final result =
        await Process.run('cmd', ['/c', 'mklink', '/D', linkPath, targetPath]);

    if (result.exitCode != 0) {
      throw Exception('Failed to create local symlink: ${result.stderr}');
    }
  }

  /// Find project root by walking up from current directory.
  /// Returns current directory if no .php-version found.
  Future<Directory> _findProjectRoot() async {
    var current = Directory.current;

    while (true) {
      final versionFile = File(
        p.join(current.path, PvmConstants.phpVersionFileName),
      );

      if (await versionFile.exists()) {
        return current;
      }

      if (current.parent.path == current.path) {
        break; // Reached filesystem root
      }

      current = current.parent;
    }

    // No .php-version found, use current directory as root
    return Directory.current;
  }
}
