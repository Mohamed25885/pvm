import 'dart:io';
import 'package:path/path.dart' as p;

import '../core/os_manager.dart';
import '../core/process_manager.dart';
import '../interfaces/i_version_activator.dart';

/// Linux version activator - uses update-alternatives or symlinks.
class LinuxVersionActivator implements IVersionActivator {
  final IOSManager _osManager;
  final IProcessManager _processManager;
  final String versionsPath;
  final String homeDirectory;
  final bool useUpdateAlternatives;

  LinuxVersionActivator({
    required IOSManager osManager,
    required IProcessManager processManager,
    required this.versionsPath,
    required this.homeDirectory,
    this.useUpdateAlternatives = true,
  })  : _osManager = osManager,
        _processManager = processManager;

  @override
  Future<void> activateGlobal(String version) async {
    final phpPath = p.join(versionsPath, version, 'bin', 'php');

    if (useUpdateAlternatives) {
      // Try update-alternatives first
      final result = await _processManager.runCaptured(
        ProcessSpec(
          executable: 'update-alternatives',
          arguments: ['--set', 'php', phpPath],
        ),
      );

      if (result.exitCode != 0) {
        // Fallback to symlink
        await _createGlobalSymlink(version);
      }
    } else {
      await _createGlobalSymlink(version);
    }
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

    // Create symlink
    await _osManager.createSymLink(version, targetPath, linkPath);
  }

  Future<void> _createGlobalSymlink(String version) async {
    final targetPath = p.join(versionsPath, version, 'bin', 'php');
    final linkPath = p.join(homeDirectory, '.pvm', 'php');

    // Create ~/.pvm directory if needed
    await Directory(p.join(homeDirectory, '.pvm')).create(recursive: true);

    // Create symlink
    await _osManager.createSymLink(version, targetPath, linkPath);
  }
}
