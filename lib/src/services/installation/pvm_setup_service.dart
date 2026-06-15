import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/console.dart';
import '../../core/constants.dart';
import '../../core/installation_requirements.dart';
import '../../core/os_manager.dart';
import '../../core/pvm_paths.dart';
import '../../interfaces/i_environment_configurator.dart';
import 'setup_preflight.dart';

class PvmSetupService {
  final IOSManager _osManager;
  final IEnvironmentConfigurator _configurator;
  final Console _console;
  final SetupPreflight _preflight;

  PvmSetupService({
    required IOSManager osManager,
    required IEnvironmentConfigurator configurator,
    required Console console,
    SetupPreflight? preflight,
  }) : _osManager = osManager,
       _configurator = configurator,
       _console = console,
       _preflight = preflight ?? SetupPreflight(osManager, configurator);

  Future<SetupCheckResult> run({
    required bool dryRun,
    required bool skipConfirm,
    String? versionsHomeOverride,
  }) async {
    final paths = PvmPaths.fromEnvironment(
      _osManager.currentEnvironment,
      programDirectoryFallback: _osManager.programDirectory,
    );
    final resolvedVersions =
        versionsHomeOverride != null && versionsHomeOverride.trim().isNotEmpty
        ? p.normalize(versionsHomeOverride.trim())
        : paths.versionsHome;
    final effectivePaths = PvmPaths(
      pvmHome: paths.pvmHome,
      versionsHome: resolvedVersions,
    );

    final globalSlot = p.join(
      _osManager.getHomeDirectory(),
      PvmConstants.pvmDirName,
    );
    final pathEntries = [effectivePaths.pvmHome, globalSlot];

    final preflight = await _preflight.run(
      paths: effectivePaths,
      plannedPathEntries: pathEntries,
    );
    if (!preflight.success) {
      return preflight;
    }

    _printPlan(effectivePaths, pathEntries);

    if (dryRun) {
      return const SetupCheckResult.ok();
    }

    if (!skipConfirm && _console.hasTerminal) {
      final ok = await _console.confirm(
        'Apply these changes?',
        defaultYes: false,
      );
      if (!ok) {
        return const SetupCheckResult.fail(
          SetupFailureReason.pathUpdateFailed,
          'Setup cancelled.',
        );
      }
    }

    await _ensureVersionsDirectory(effectivePaths.versionsHome);

    if (_configurator.canPersistEnvironment) {
      try {
        await _configurator.setUserEnvironmentVariable(
          PvmConstants.envPvmHome,
          effectivePaths.pvmHome,
        );
        await _configurator.setUserEnvironmentVariable(
          PvmConstants.envPvmVersionsHome,
          effectivePaths.versionsHome,
        );
        await _configurator.ensurePathEntries(pathEntries);
      } catch (e) {
        return SetupCheckResult.fail(
          SetupFailureReason.cannotWriteEnvironment,
          e.toString(),
        );
      }
    } else {
      _console.printWarning(
        'Set PVM_HOME, PVM_VERSIONS_HOME, and PATH manually on this platform.',
      );
    }

    _console.print('Setup complete.');
    return const SetupCheckResult.ok();
  }

  void _printPlan(PvmPaths paths, List<String> pathEntries) {
    _console.print('PVM setup plan:');
    _console.print('  PVM_HOME           = ${paths.pvmHome}');
    _console.print('  PVM_VERSIONS_HOME  = ${paths.versionsHome}');
    _console.print('  PATH entries       = ${pathEntries.join('; ')}');
  }

  Future<void> _ensureVersionsDirectory(String versionsHome) async {
    final dir = Directory(versionsHome);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}
