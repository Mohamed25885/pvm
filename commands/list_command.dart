import 'package:args/command_runner.dart';

import '../interfaces/os_manager.dart';

class ListCommand extends Command<int> {
  @override
  final String name = 'list';

  @override
  final String description = 'List all available PHP versions';

  final IOSManager _osManager;

  ListCommand(this._osManager);

  @override
  Future<int> run() async {
    final versions =
        _osManager.getAvailableVersions(_osManager.phpVersionsPath);
    if (versions.isEmpty) {
      print('No PHP versions found in ${_osManager.phpVersionsPath}');
      return 1;
    }
    print(versions.join('\n'));
    return 0;
  }
}
