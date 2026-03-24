import 'dart:io';

import 'package:args/command_runner.dart';

import 'lib/src/commands/global_command.dart';
import 'lib/src/commands/use_command.dart';
import 'lib/src/commands/list_command.dart';
import 'lib/src/commands/php_command.dart';
import 'lib/src/core/gitignore_service.dart';
import 'lib/src/core/os_manager.dart';
import 'lib/src/core/php_version_manager.dart';
import 'lib/src/core/process_manager.dart';
import 'lib/src/managers/mock_os_manager.dart';
import 'lib/src/managers/windows_os_manager.dart';
import 'lib/src/process/io_process_manager.dart';

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
  late final IProcessManager _processManager;
  late final PhpVersionManager _phpVersionManager;
  late final GitIgnoreService _gitIgnoreService;

  PvmCommandRunner({
    IOSManager? osManager,
    IProcessManager? processManager,
    PhpVersionManager? phpVersionManager,
    GitIgnoreService? gitIgnoreService,

    /// Overrides the current directory for MockOSManager.
    /// Used in tests to isolate from the real CWD.
    String? mockCurrentDirectory,
  }) : super('pvm',
            'PHP Version Manager - Manage multiple PHP versions on Windows') {
    _osManager = osManager ?? WindowsOSManager();
    _processManager = processManager ?? IOProcessManager();
    _phpVersionManager = phpVersionManager ?? PhpVersionManager();
    _gitIgnoreService = gitIgnoreService ?? GitIgnoreService();

    // Apply mock current directory if provided and osManager is MockOSManager
    if (mockCurrentDirectory != null) {
      final mos = _osManager;
      if (mos is MockOSManager) {
        mos.mockCurrentDirectory = mockCurrentDirectory;
      }
    }

    addCommand(GlobalCommand(_osManager));
    addCommand(UseCommand(_osManager, _phpVersionManager, _gitIgnoreService));
    addCommand(ListCommand(_osManager));
    addCommand(PhpCommand(_osManager, _processManager));
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
