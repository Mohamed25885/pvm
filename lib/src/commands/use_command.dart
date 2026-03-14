import 'package:args/command_runner.dart';

import '../core/os_manager.dart';

class UseCommand extends Command<int> {
  @override
  final String name = 'use';

  @override
  final String description = 'Set the local PHP version (project-specific)';

  final IOSManager _osManager;

  UseCommand(this._osManager);

  @override
  Future<int> run() async {
    final version = argResults?.rest.firstOrNull;
    if (version == null) {
      print('Error: No version specified');
      return 1;
    }

    if (argResults?.rest.length != 1) {
      print('Error: Too many arguments. Usage: pvm use <version>');
      return 1;
    }

    final available =
        _osManager.getAvailableVersions(_osManager.phpVersionsPath);
    if (!available.contains(version)) {
      print(
          'Error: Version $version not found. Available: ${available.join(", ")}');
      return 1;
    }

    try {
      final localPath = _osManager.localPath;
      final sourcePath = '${_osManager.phpVersionsPath}\\$version';

      final result =
          await _osManager.createSymLink(version, sourcePath, localPath);
      print('Local link created: ${result.to} -> ${result.from}');
      return 0;
    } catch (e) {
      print('Error: $e');
      return 1;
    }
  }
}
