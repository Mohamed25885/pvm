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

  /// Run `php` with [args].
  ///
  /// When [phpExecutable] is provided, that path is used verbatim and
  /// [_executableResolver] is bypassed. This lets `pvm exec` pick a specific
  /// installed version without going through the `<projectRoot>/.pvm` link.
  ///
  /// When [environment] is provided, it overrides `Platform.environment`
  /// in the spawned process.
  Future<int> runPhp(
    List<String> args, {
    String? workingDirectory,
    String? phpExecutable,
    Map<String, String>? environment,
  }) async {
    final rootPath = workingDirectory ?? _osManager.currentDirectory;
    final phpExe = phpExecutable ??
        await _executableResolver.resolvePhpExecutable(rootPath);

    final spec = ProcessSpec(
      executable: phpExe,
      arguments: args,
      workingDirectory: rootPath,
      environment: environment ?? Platform.environment,
    );

    return await _processManager.runInteractive(spec);
  }

  /// Run a PHP script file via `php <scriptPath> <args...>`.
  ///
  /// See [runPhp] for [phpExecutable] / [environment] semantics.
  Future<int> runScript(
    String scriptPath,
    List<String> args, {
    String? workingDirectory,
    String? phpExecutable,
    Map<String, String>? environment,
  }) async {
    final rootPath = workingDirectory ?? _osManager.currentDirectory;
    final phpExe = phpExecutable ??
        await _executableResolver.resolvePhpExecutable(rootPath);

    final spec = ProcessSpec(
      executable: phpExe,
      arguments: [scriptPath, ...args],
      workingDirectory: rootPath,
      environment: environment ?? Platform.environment,
    );

    return await _processManager.runInteractive(spec);
  }
}
