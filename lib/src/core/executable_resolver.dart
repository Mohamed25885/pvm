import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/platform_constants.dart';
import '../core/os_manager.dart';

abstract class IExecutableResolver {
  Future<String> resolvePhpExecutable(String projectPath);
  String get phpExecutableName;
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
      throw Exception('PHP executable not found at $phpExe');
    }

    return phpExe;
  }
}
