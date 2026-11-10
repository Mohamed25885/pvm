import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/os_manager.dart';
import '../domain/exceptions.dart';
import '../domain/project.dart';
import '../interfaces/i_version_activator.dart';

/// Version activator for every platform: points the `.pvm` link (global in
/// the home directory, local in the project root) at `versions/<version>`.
/// The OS manager decides how the link is made (junction on Windows,
/// symlink elsewhere).
class LinkVersionActivator implements IVersionActivator {
  final IOSManager _osManager;
  final String versionsPath;
  final String homeDirectory;

  LinkVersionActivator({
    required this._osManager,
    required this.versionsPath,
    required this.homeDirectory,
  });

  @override
  Future<void> activateGlobal(String version) async {
    final targetPath = p.join(versionsPath, version);
    final linkPath = p.join(homeDirectory, PvmConstants.pvmDirName);

    await _osManager.createSymLink(version, targetPath, linkPath);
  }

  @override
  Future<void> activateLocal(String version) async {
    final project = await Project.locate(_osManager);
    final targetPath = p.join(versionsPath, version);
    final linkPath = p.join(
      project.rootDirectory.path,
      PvmConstants.pvmDirName,
    );
    final globalSlot = p.join(homeDirectory, PvmConstants.pvmDirName);
    if (p.equals(p.normalize(linkPath), p.normalize(globalSlot))) {
      // Never let a local activation overwrite the global link (S3).
      throw const PvmException(
        'Refusing to create a local link in the home directory: '
        'it would replace the global version link.',
      );
    }

    await _osManager.createSymLink(version, targetPath, linkPath);
  }
}
