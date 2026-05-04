import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/os_manager.dart';
import '../domain/project.dart';
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
    final linkPath = p.join(homeDirectory, PvmConstants.pvmDirName);

    await _osManager.createSymLink(version, targetPath, linkPath);
  }

  @override
  Future<void> activateLocal(String version) async {
    final project = await Project.findFromPath(_osManager.currentDirectory);
    final targetPath = p.join(versionsPath, version);
    final linkPath =
        p.join(project.rootDirectory.path, PvmConstants.pvmDirName);

    await _osManager.createSymLink(version, targetPath, linkPath);
  }
}
