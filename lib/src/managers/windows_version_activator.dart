import 'dart:io';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/os_manager.dart';
import '../interfaces/i_version_activator.dart';

/// Windows version activator - uses mklink for symlinks.
class WindowsVersionActivator implements IVersionActivator {
  final IOSManager _osManager;
  final String versionsPath;
  final String homeDirectory;

  WindowsVersionActivator({
    required IOSManager osManager,
    required this.versionsPath,
    required this.homeDirectory,
  }) : _osManager = osManager;

  @override
  Future<void> activateGlobal(String version) async {
    final targetPath = p.join(versionsPath, version);
    final linkPath = p.join(homeDirectory, '.pvm');

    await _osManager.createSymLink(version, targetPath, linkPath);
  }

  @override
  Future<void> activateLocal(String version) async {
    // Find project root by walking up from current directory
    final projectRoot = await _findProjectRoot();
    final targetPath = p.join(versionsPath, version);
    final linkPath = p.join(projectRoot.path, PvmConstants.pvmDirName);

    await _osManager.createSymLink(version, targetPath, linkPath);
  }

  /// Find project root by walking up from current directory.
  /// Returns current directory if no .php-version found.
  Future<Directory> _findProjectRoot() async {
    var current = Directory(_osManager.currentDirectory);

    while (true) {
      final versionFilePath =
          p.join(current.path, PvmConstants.phpVersionFileName);
      if (await _osManager.fileExists(versionFilePath)) {
        return current;
      }

      if (current.parent.path == current.path) {
        break; // Reached filesystem root
      }

      current = current.parent;
    }

    // No .php-version found, use current directory as root
    return Directory(_osManager.currentDirectory);
  }
}
