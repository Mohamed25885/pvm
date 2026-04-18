import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'lib/src/console/console_io.dart';
import 'lib/src/core/exit_codes.dart';
import 'lib/src/managers/windows_os_manager.dart';
import 'lib/src/core/gitignore_service.dart';
import 'lib/src/core/php_version_manager.dart';
import 'lib/src/services/php_executor.dart';
import 'lib/src/commands/use_command.dart';
import 'lib/src/commands/global_command.dart';
import 'lib/src/commands/list_command.dart';
import 'lib/src/commands/php_command.dart';
import 'lib/src/commands/composer_command.dart';
import 'lib/src/commands/version_flag.dart';
import 'lib/src/process/io_process_manager.dart';
import 'lib/src/version.dart';

class PvmCommandRunner extends CommandRunner<int> {
  PvmCommandRunner(String name, String description) : super(name, description);

  ArgParser? _parser;
  @override
  ArgParser get argParser => _parser ??= ArgParser(allowTrailingOptions: true);
}

Future<int> main(List<String> arguments) async {
  final console = ConsoleIO();
  final osManager = WindowsOSManager();
  final gitIgnoreService = GitIgnoreService(osManager, console);
  final phpVersionManager = PhpVersionManager(console);
  final phpExecutor = PhpExecutor(
    processManager: IOProcessManager(),
    osManager: osManager,
  );

  final runner = PvmCommandRunner('pvm', 'PHP Version Manager');

  runner.addCommand(UseCommand(
    osManager,
    phpVersionManager,
    gitIgnoreService,
    console,
  ));
  runner.addCommand(GlobalCommand(osManager, console));
  runner.addCommand(ListCommand(osManager, console));
  runner.addCommand(PhpCommand(phpExecutor, osManager, console));
  runner.addCommand(ComposerCommand(phpExecutor, osManager, console));
  runner.addCommand(VersionFlag(console));

  // Intercept top-level --version / -v to output custom format
  if (arguments.isNotEmpty &&
      (arguments.first == '--version' || arguments.first == '-v')) {
    console.print('PVM version: $packageVersion');
    return ExitCode.success;
  }

  try {
    return await runner.run(arguments) ?? ExitCode.success;
  } on UsageException catch (e) {
    console.printError(e.message);
    return ExitCode.usageError;
  } catch (e) {
    console.printError('Unexpected error: $e');
    return ExitCode.generalError;
  }
}
