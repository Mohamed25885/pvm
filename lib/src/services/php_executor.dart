import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/os_manager.dart';
import '../core/path_env.dart';
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
  }) : _processManager = processManager,
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
    final phpExe =
        phpExecutable ??
        await _executableResolver.resolvePhpExecutable(rootPath);

    final spec = ProcessSpec(
      executable: phpExe,
      arguments: args,
      workingDirectory: rootPath,
      environment: _envWithPhp(phpExe, environment),
    );

    return await _processManager.runInteractive(spec);
  }

  /// Child processes (Composer scripts, `artisan` spawning `php`, …) must see
  /// the selected PHP first on PATH, not the global one (B8).
  Map<String, String> _envWithPhp(
    String phpExe,
    Map<String, String>? environment,
  ) => prependToPath(
    environment ?? _osManager.currentEnvironment,
    p.dirname(phpExe),
    separator: Platform.isWindows ? ';' : ':',
    caseInsensitiveKeys: Platform.isWindows,
  );

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
    final phpExe =
        phpExecutable ??
        await _executableResolver.resolvePhpExecutable(rootPath);

    final spec = ProcessSpec(
      executable: phpExe,
      arguments: [scriptPath, ...args],
      workingDirectory: rootPath,
      environment: _envWithPhp(phpExe, environment),
    );

    return await _processManager.runInteractive(spec);
  }
}
