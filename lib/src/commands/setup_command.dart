import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../interfaces/i_environment_configurator.dart';
import '../services/installation/pvm_setup_service.dart';

class SetupCommand extends Command<int> {
  @override
  final String name = 'setup';

  @override
  final String description =
      'Configure PVM directories, optional PVM_HOME/PVM_VERSIONS_HOME, and PATH';

  @override
  final ArgParser argParser = ArgParser()
    ..addFlag('dry-run', negatable: false)
    ..addFlag('yes', abbr: 'y', negatable: false)
    ..addOption('versions-home');

  final Console _console;
  final PvmSetupService _service;

  SetupCommand({
    required IOSManager osManager,
    required IEnvironmentConfigurator configurator,
    required Console console,
    PvmSetupService? service,
  }) : _console = console,
       _service =
           service ??
           PvmSetupService(
             osManager: osManager,
             configurator: configurator,
             console: console,
           );

  @override
  Future<int> run() async {
    final result = await _service.run(
      dryRun: argResults!['dry-run'] as bool,
      skipConfirm: argResults!['yes'] as bool,
      versionsHomeOverride: argResults!['versions-home'] as String?,
    );

    if (!result.success) {
      _console.printError(result.message ?? 'Setup failed.');
      return ExitCode.generalError;
    }

    return ExitCode.success;
  }
}
