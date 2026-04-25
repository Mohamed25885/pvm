import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/platform_constants.dart';
import '../core/os_manager.dart';

abstract class IExecutableResolver {
  Future<String> resolvePhpExecutable(String projectPath);
  String get phpExecutableName;
}

class PhpExecutableNotFoundException implements Exception {
  final String path;
  PhpExecutableNotFoundException(this.path);

  @override
  String toString() =>
      'PHP executable not found at $path.\n'
      'Run `pvm use <version>` to activate a version for this project, '
      'or `pvm global <version>` to set a global default.';
}

class ExecutableResolver implements IExecutableResolver {
  final PlatformConstants _platformConstants;
  final IOSManager _osManager;

  ExecutableResolver({
    required PlatformConstants platformConstants,
    required IOSManager osManager,
  })  : _platformConstants = platformConstants,
        _osManager = osManager;

  @override
  String get phpExecutableName => _platformConstants.phpExecutableName;

  @override
  Future<String> resolvePhpExecutable(String projectPath) async {
    final phpExe = p.join(
      projectPath,
      PvmConstants.pvmDirName,
      _platformConstants.phpExecutableName,
    );

    if (!(await _osManager.fileExists(phpExe))) {
      throw PhpExecutableNotFoundException(phpExe);
    }

    return phpExe;
  }
}
