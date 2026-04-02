import 'dart:io';

import 'package:args/command_runner.dart';

import 'lib/src/commands/global_command.dart';
import 'lib/src/commands/use_command.dart';
import 'lib/src/commands/list_command.dart';
import 'lib/src/commands/php_command.dart';
import 'lib/src/commands/composer_command.dart';
import 'lib/src/core/gitignore_service.dart';
import 'lib/src/core/os_manager.dart';
import 'lib/src/core/php_version_manager.dart';
import 'lib/src/core/process_manager.dart';
import 'lib/src/managers/mock_os_manager.dart';
import 'lib/src/managers/windows_os_manager.dart';
import 'lib/src/process/io_process_manager.dart';
import 'lib/src/services/php_executor.dart';
import 'lib/src/version.dart';

/// Returns the current package version from generated version.dart.
String _readVersion() {
  return packageVersion;
}

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
    final phpExecutor = PhpExecutor(
      processManager: _processManager,
      osManager: _osManager,
    );
    addCommand(PhpCommand(_osManager, phpExecutor));
    addCommand(ComposerCommand(_osManager, phpExecutor));
  }

  @override
  Future<int?> run(Iterable<String> args) async {
    // If a subcommand is specified (first arg doesn't start with '-'), delegate
    // to CommandRunner immediately so that flags like '--version' are passed
    // to the subcommand instead of being intercepted globally.
    if (args.isNotEmpty && !args.first.startsWith('-')) {
      final result = await super.run(args);
      // CommandRunner returns null when help is displayed; convert to 0
      return result ?? 0;
    }

    // Check for version flag (only when no subcommand is specified)
    if (args.contains('--version') || args.contains('-v')) {
      print('PVM version: ${_readVersion()}');
      return 0;
    }

    // Check for help flags (only when no subcommand is specified)
    if (args.isEmpty ||
        args.any((arg) => arg == 'help' || arg == '--help' || arg == '-h')) {
      print(usage);
      return 0;
    }

    return super.run(args);
  }
}
