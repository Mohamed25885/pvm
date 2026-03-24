import 'dart:io';

import '../core/os_manager.dart';
import '../core/process_manager.dart';

class PhpExecutor {
  final IProcessManager _processManager;
  final IOSManager _osManager;

  PhpExecutor({
    required IProcessManager processManager,
    required IOSManager osManager,
  })  : _processManager = processManager,
        _osManager = osManager;

  Future<int> runPhp(List<String> args, {String? workingDirectory}) async {
    final rootPath = workingDirectory ?? _osManager.currentDirectory;
    final phpExe = await _resolvePhpExecutable(rootPath);

    final spec = ProcessSpec(
      executable: phpExe,
      arguments: args,
      workingDirectory: rootPath,
      environment: Platform.environment,
    );

    return await _processManager.runInteractive(spec);
  }

  Future<int> runScript(
    String scriptPath,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final rootPath = workingDirectory ?? _osManager.currentDirectory;
    final phpExe = await _resolvePhpExecutable(rootPath);

    final spec = ProcessSpec(
      executable: phpExe,
      arguments: [scriptPath, ...args],
      workingDirectory: rootPath,
      environment: Platform.environment,
    );

    return await _processManager.runInteractive(spec);
  }

  Future<String> _resolvePhpExecutable(String rootPath) async {
    final phpExe =
        Platform.isWindows ? '$rootPath\\.pvm\\php.exe' : '$rootPath/.pvm/php';

    if (!(await _osManager.fileExists(phpExe))) {
      throw Exception('PHP executable not found at $phpExe');
    }

    return phpExe;
  }
}
