import 'package:args/command_runner.dart';

import '../interfaces/os_manager.dart';

class GlobalCommand extends Command<int> {
  @override
  final String name = 'global';

  @override
  final String description = 'Set the global PHP version (system-wide)';

  final IOSManager _osManager;

  GlobalCommand(this._osManager);

  @override
  Future<int> run() async {
    final version = argResults?.rest.firstOrNull;
    if (version == null) {
      print('Error: No version specified');
      return 1;
    }

    if (argResults?.rest.length != 1) {
      print('Error: Too many arguments. Usage: pvm global <version>');
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
      final homeDir = _osManager.getHomeDirectory();
      final globalPath = '$homeDir\\.pvm';
      final sourcePath = '${_osManager.phpVersionsPath}\\$version';

      final result =
          await _osManager.createSymLink(version, sourcePath, globalPath);
      print('Global link created: ${result.to} -> ${result.from}');
      print('Add "$globalPath" to your PATH to use globally');
      return 0;
    } catch (e) {
      print('Error: $e');
      return 1;
    }
  }
}
