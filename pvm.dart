import 'dart:io';

import 'package:args/command_runner.dart';

import 'lib/src/commands/global_command.dart';
import 'lib/src/commands/use_command.dart';
import 'lib/src/commands/list_command.dart';
import 'lib/src/commands/php_command.dart';
import 'lib/src/core/os_manager.dart';
import 'lib/src/managers/windows_os_manager.dart';
import 'lib/src/process/process.dart';

void main(List<String> arguments) async {
  final runner = PvmCommandRunner();
  try {
    await runner.run(arguments);
  } catch (e) {
    print(e.toString());
    exitCode = 1;
  } finally {
    runner.dispose();
  }
}

class PvmCommandRunner extends CommandRunner<int> {
  late final IOSManager _osManager;
  late final ManagedProcessRunner _phpRunner;

  PvmCommandRunner({IOSManager? osManager})
      : super('pvm',
            'PHP Version Manager - Manage multiple PHP versions on Windows') {
    _osManager = osManager ?? WindowsOSManager();
    _phpRunner = ManagedProcessRunner();

    addCommand(GlobalCommand(_osManager));
    addCommand(UseCommand(_osManager));
    addCommand(ListCommand(_osManager));
    addCommand(PhpCommand(_osManager, _phpRunner));
  }

  @override
  Future<int?> run(Iterable<String> args) async {
    if (args.isEmpty ||
        args.any((arg) => arg == 'help' || arg == '--help' || arg == '-h')) {
      print(usage);
      return 0;
    }
    return super.run(args);
  }

  void dispose() {
    _phpRunner.dispose();
  }
}
