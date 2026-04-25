import 'dart:io';
import 'package:path/path.dart' as p;

import '../core/os_manager.dart';
import '../interfaces/i_version_activator.dart';

/// macOS version activator - uses symlinks.
class MacOSVersionActivator implements IVersionActivator {
  final IOSManager _osManager;
  final String versionsPath;
  final String homeDirectory;

  MacOSVersionActivator({
    required IOSManager osManager,
    required this.versionsPath,
    required this.homeDirectory,
  }) : _osManager = osManager;

  @override
  Future<void> activateGlobal(String version) async {
    await _createGlobalSymlink(version);
  }

  @override
  Future<void> activateLocal(String version) async {
    // Create symlink in project .pvm directory
    final projectDir = _osManager.currentDirectory;
    final localPvmDir = p.join(projectDir, '.pvm');
    final linkPath = p.join(localPvmDir, 'php');
    final targetPath = p.join(versionsPath, version, 'bin', 'php');

    // Create .pvm directory if needed
    await Directory(localPvmDir).create(recursive: true);

    await _osManager.createSymLink(version, targetPath, linkPath);
  }

  Future<void> _createGlobalSymlink(String version) async {
    final targetPath = p.join(versionsPath, version, 'bin', 'php');
    final linkPath = p.join(homeDirectory, '.pvm', 'php');

    // Create ~/.pvm directory if needed
    await Directory(p.join(homeDirectory, '.pvm')).create(recursive: true);

    await _osManager.createSymLink(version, targetPath, linkPath);
  }
}
