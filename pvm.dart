import 'dart:io';

import 'package:args/command_runner.dart';

import 'commands/global_command.dart';
import 'commands/use_command.dart';
import 'commands/list_command.dart';
import 'commands/php_command.dart';
import 'interfaces/os_manager.dart';
import 'utils/windows_os_manager.dart';
import 'utils/job_object_manager.dart';

void main(List<String> arguments) async {
  final runner = PvmCommandRunner();
  try {
    await runner.run(arguments);
  } catch (e) {
    print(e.toString());
    exitCode = 1;
  }
}

class PvmCommandRunner extends CommandRunner<int> {
  late final IOSManager _osManager;
  late final ManagedProcessRunner  _phpRunner;

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
}
