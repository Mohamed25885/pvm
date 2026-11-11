import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/os_manager.dart';
import '../core/path_env.dart';
import '../core/platform_info.dart';
import '../core/process_manager.dart';
import '../core/executable_resolver.dart';
import '../core/php_layout.dart';
import '../domain/version_registry.dart';
import 'slot_ini.dart';

class PhpExecutor {
  final IProcessManager _processManager;
  final IOSManager _osManager;
  final IExecutableResolver _executableResolver;
  final PlatformInfo _platform;

  PhpExecutor({
    required this._processManager,
    required this._osManager,
    required this._executableResolver,
    PlatformInfo? platformInfo,
  }) : _platform = platformInfo ?? createPlatformInfo();

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

    final ini = await _slotIni(phpExe);
    final spec = ProcessSpec(
      executable: phpExe,
      arguments: [...?ini?.args, ...args],
      workingDirectory: rootPath,
      environment: {..._envWithPhp(phpExe, environment), ...?ini?.env},
    );

    return await _processManager.runInteractive(spec);
  }

  /// The slot ini for [phpExe]'s slot; null for unrecorded or linked slots.
  Future<({List<String> args, Map<String, String> env})?> _slotIni(
    String phpExe,
  ) async {
    try {
      final layout = PhpLayout.forPlatform(_platform);
      var slot = layout.binSubdirectory.isEmpty
          ? p.dirname(phpExe)
          : p.dirname(p.dirname(phpExe));
      // `.pvm` is a link to the slot: use the real slot path.
      if (Directory(slot).existsSync()) {
        slot = Directory(slot).resolveSymbolicLinksSync();
      }
      final record = await VersionRegistry.readSlotRecord(slot);
      if (record == null) return null;
      return SlotIni(slot, record, _platform).childInvocation();
    } catch (_) {
      return null; // unreadable record: run PHP as before
    }
  }

  /// Child processes (Composer scripts, `artisan` spawning `php`, …) must see
  /// the selected PHP first on PATH, not the global one (B8).
  Map<String, String> _envWithPhp(
    String phpExe,
    Map<String, String>? environment,
  ) => prependToPath(
    environment ?? _osManager.currentEnvironment,
    p.dirname(phpExe),
    separator: _platform.pathSeparator,
    caseInsensitiveKeys: _platform.osType == 'windows',
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

    final ini = await _slotIni(phpExe);
    final spec = ProcessSpec(
      executable: phpExe,
      arguments: [...?ini?.args, scriptPath, ...args],
      workingDirectory: rootPath,
      environment: {..._envWithPhp(phpExe, environment), ...?ini?.env},
    );

    return await _processManager.runInteractive(spec);
  }
}
