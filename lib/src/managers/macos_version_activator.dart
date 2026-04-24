import 'dart:io';
import 'package:path/path.dart' as p;

import '../interfaces/i_version_activator.dart';

/// macOS version activator - uses symlinks.
class MacOSVersionActivator implements IVersionActivator {
  final String versionsPath;
  final String homeDirectory;

  MacOSVersionActivator({
    required this.versionsPath,
    required this.homeDirectory,
  });

  @override
  Future<void> activateGlobal(String version) async {
    await _createGlobalSymlink(version);
  }

  @override
  Future<void> activateLocal(String version) async {
    // Create symlink in project .pvm directory
    final projectDir = Directory.current.path;
    final localPvmDir = p.join(projectDir, '.pvm');
    final linkPath = p.join(localPvmDir, 'php');
    final targetPath = p.join(versionsPath, version, 'bin', 'php');

    // Create .pvm directory if needed
    await Directory(localPvmDir).create(recursive: true);

    // Create symlink
    final result = await Process.run('ln', ['-sf', targetPath, linkPath]);

    if (result.exitCode != 0) {
      throw Exception('Failed to create local symlink: ${result.stderr}');
    }
  }

  Future<void> _createGlobalSymlink(String version) async {
    final targetPath = p.join(versionsPath, version, 'bin', 'php');
    final linkPath = p.join(homeDirectory, '.pvm', 'php');

    // Create ~/.pvm directory if needed
    await Directory(p.join(homeDirectory, '.pvm')).create(recursive: true);

    // Create symlink using ln -s
    final result = await Process.run('ln', ['-sf', targetPath, linkPath]);

    if (result.exitCode != 0) {
      throw Exception('Failed to create symlink: ${result.stderr}');
    }
  }
}
