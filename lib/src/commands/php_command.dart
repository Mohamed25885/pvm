import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../services/php_executor.dart';
import '../domain/exceptions.dart';
import '../domain/project.dart';

class PhpCommand extends Command<int> {
  @override
  final String name = 'php';

  @override
  final String description = 'Run PHP with the local version configuration';

  final PhpExecutor _phpExecutor;
  final IOSManager _osManager;
  final Console _console;

  PhpCommand(this._phpExecutor, this._osManager, this._console);

  ArgParser? _parser;

  @override
  ArgParser get argParser => _parser ??= ArgParser.allowAnything();

  @override
  Future<int> run() async {
    try {
      final project = await Project.findFromPath(_osManager.currentDirectory);
      final args = argResults!.rest;
      final exitCode = await _phpExecutor.runPhp(
        args,
        workingDirectory: project.rootDirectory.path,
      );
      return exitCode;
    } on ProjectNotConfiguredException catch (e) {
      _console.printError(e.message);
      return ExitCode.configurationError;
    } on CorruptedConfigurationException catch (e) {
      _console.printError(e.message);
      return ExitCode.configurationError;
    } catch (e) {
      _console.printError('Error running PHP: $e');
      return ExitCode.generalError;
    }
  }
}
