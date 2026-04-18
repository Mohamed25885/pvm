import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/console.dart';
import '../core/constants.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../domain/exceptions.dart';
import '../domain/project.dart';
import '../services/php_executor.dart';

class ComposerCommand extends Command<int> {
  @override
  final String name = 'composer';

  @override
  final String description = 'Run Composer using the local PHP version';

  final PhpExecutor _phpExecutor;
  final IOSManager _osManager; // Needed for PATH lookup
  final Console _console;

  ComposerCommand(this._phpExecutor, this._osManager, this._console);

  ArgParser? _parser;

  @override
  ArgParser get argParser => _parser ??= ArgParser.allowAnything();

  @override
  Future<int> run() async {
    try {
      final composerScript = await _findComposerScript();
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

  Future<String?> _findComposerScript() async {
    final pathEnv = _osManager.currentEnvironment['PATH'] ?? '';
    final separator = Platform.isWindows ? ';' : ':';
    final dirs = pathEnv.split(separator);

    final candidates = Platform.isWindows
        ? [
            PvmConstants.composerBat,
            PvmConstants.composerCmd,
            PvmConstants.composerPhar
          ]
        : ['composer', PvmConstants.composerPhar];

    for (final dir in dirs) {
      for (final name in candidates) {
        final candidate = p.join(dir, name);
        if (await _osManager.fileExists(candidate)) {
          if (candidate.endsWith('.bat') || candidate.endsWith('.cmd')) {
            // Look for composer.phar in same directory
            final phar = p.join(dir, PvmConstants.composerPhar);
            if (await _osManager.fileExists(phar)) {
              return phar;
            }
            // Batch file without .phar: warn but continue looking
            _console.printWarning(
              'Found $name but no composer.phar in the same directory.\n'
              'This will use system PHP instead of your project PHP version.\n'
              'To fix: download composer.phar to $dir',
            );
            continue;
          }
          return candidate;
        }
      }
    }
    return null;
  }
}
