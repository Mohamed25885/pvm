import 'dart:io';

import '../core/os_manager.dart';
import '../core/process_manager.dart';
import '../core/executable_resolver.dart';

class PhpExecutor {
  final IProcessManager _processManager;
  final IOSManager _osManager;
  final IExecutableResolver _executableResolver;

  PhpExecutor({
    required IProcessManager processManager,
    required IOSManager osManager,
    required IExecutableResolver executableResolver,
  })  : _processManager = processManager,
        _osManager = osManager,
        _executableResolver = executableResolver;

  Future<int> runPhp(List<String> args, {String? workingDirectory}) async {
    final rootPath = workingDirectory ?? _osManager.currentDirectory;
    final phpExe = await _executableResolver.resolvePhpExecutable(rootPath);

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
    final phpExe = await _executableResolver.resolvePhpExecutable(rootPath);

    final spec = ProcessSpec(
      executable: phpExe,
      arguments: [scriptPath, ...args],
      workingDirectory: rootPath,
      environment: Platform.environment,
    );

    return await _processManager.runInteractive(spec);
  }
}
