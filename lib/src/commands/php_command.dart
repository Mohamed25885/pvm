import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/os_manager.dart';
import '../process/process.dart';

class PhpCommand extends Command<int> {
  @override
  final String name = 'php';

  @override
  final String description = 'Run PHP with the local version configuration';

  final IOSManager _osManager;
  final ManagedProcessRunner _phpRunner;

  PhpCommand(this._osManager, this._phpRunner);

  @override
  String get invocation => 'pvm php [arguments]';

  @override
  ArgParser get argParser => ArgParser.allowAnything();

  @override
  Future<int> run() async {
    final localPath = _osManager.localPath;

    if (!await _osManager.directoryExists(localPath)) {
      print(
          'Error: No local version configured. Run "pvm use <version>" first.');
      return 1;
    }

    final phpExe = '$localPath\\php.exe';
    if (!await _osManager.fileExists(phpExe)) {
      print('Error: PHP executable not found at $phpExe');
      return 1;
    }

    try {
      final args = argResults?.rest ?? [];
      final exitCode = await _phpRunner.run(phpExe, args);
      return exitCode;
    } catch (e) {
      print('Error running PHP: $e');
      return 1;
    }
  }
}
