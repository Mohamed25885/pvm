import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/installation_requirements.dart';
import '../../core/os_manager.dart';
import '../../core/pvm_paths.dart';
import '../../interfaces/i_environment_configurator.dart';

class SetupPreflight {
  final IOSManager _osManager;
  final IEnvironmentConfigurator _configurator;
  final Future<bool> Function(String path) _isWritable;

  SetupPreflight(
    this._osManager,
    this._configurator, {
    Future<bool> Function(String path)? isWritable,
  }) : _isWritable = isWritable ?? _defaultWritable;

  static Future<bool> _defaultWritable(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return true;
      final probe = File(p.join(path, '.pvm-setup-write-probe'));
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SetupCheckResult> run({
    required PvmPaths paths,
    required List<String> plannedPathEntries,
  }) async {
    if (!await _osManager.directoryExists(paths.pvmHome)) {
      return SetupCheckResult.fail(
        SetupFailureReason.pvmHomeNotReadable,
        'PVM home directory is missing or not readable: ${paths.pvmHome}',
      );
    }

    if (await _osManager.directoryExists(paths.versionsHome)) {
      if (!await _isWritable(paths.versionsHome)) {
        return SetupCheckResult.fail(
          SetupFailureReason.versionsHomeNotWritable,
          'Versions directory is not writable: ${paths.versionsHome}',
        );
      }
    }

    if (!_configurator.canPersistEnvironment) {
      return const SetupCheckResult.ok();
    }

    try {
      await _configurator.getPath();
    } catch (e) {
      return SetupCheckResult.fail(
        SetupFailureReason.cannotWriteEnvironment,
        'Cannot read user PATH: $e',
      );
    }

    return const SetupCheckResult.ok();
  }
}
