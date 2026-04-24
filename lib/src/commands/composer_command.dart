import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../core/composer_locator.dart';
import '../domain/exceptions.dart';
import '../domain/project.dart';
import '../services/php_executor.dart';

class ComposerCommand extends Command<int> {
  @override
  final String name = 'composer';

  @override
  final String description = 'Run Composer using the local PHP version';

  final PhpExecutor _phpExecutor;
  final IOSManager _osManager;
  final IComposerLocator _composerLocator;
  final Console _console;

  ComposerCommand(
    this._phpExecutor,
    this._osManager,
    this._composerLocator,
    this._console,
  );

  ArgParser? _parser;

  @override
  ArgParser get argParser => _parser ??= ArgParser.allowAnything();

  @override
  Future<int> run() async {
    try {
      final composerScript =
          await _composerLocator.findComposer(_osManager.currentEnvironment);
      if (composerScript == null) {
        _console.printError('Composer not found in PATH.');
        _console.print(
            'Install Composer globally or ensure composer.phar is in your PATH.');
        return ExitCode.generalError;
      }

      final project = await Project.findFromPath(_osManager.currentDirectory);
      final args = argResults!.rest;
      final exitCode = await _phpExecutor.runScript(
        composerScript,
        args,
        workingDirectory: project.rootDirectory.path,
      );
      return exitCode;
    } on ProjectNotConfiguredException catch (e) {
      _console.printError(e.message);
      return ExitCode.configurationError;
    } catch (e) {
      _console.printError('Error running Composer: $e');
      return ExitCode.generalError;
    }
  }
}
