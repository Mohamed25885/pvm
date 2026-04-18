import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../lib/src/commands/composer_command.dart';
import '../lib/src/commands/global_command.dart';
import '../lib/src/commands/list_command.dart';
import '../lib/src/commands/php_command.dart';
import '../lib/src/commands/use_command.dart';
import '../lib/src/commands/version_flag.dart';
import '../lib/src/core/console.dart';
import '../lib/src/core/gitignore_service.dart';
import '../lib/src/core/os_manager.dart';
import '../lib/src/core/php_version_manager.dart';
import '../lib/src/core/process_manager.dart';
import '../lib/src/domain/php_version.dart';
import '../lib/src/process/io_process_manager.dart';
import '../lib/src/services/php_executor.dart';
import 'mocks/mock_console.dart';

/// Private CommandRunner subclass that enables trailing options.
class _PvmTestCommandRunner extends CommandRunner<int> {
  _PvmTestCommandRunner(String name, String description)
      : super(name, description);

  ArgParser? _parser;
  @override
  ArgParser get argParser => _parser ??= ArgParser(allowTrailingOptions: true);
}

/// Test helper that creates a CommandRunner with all PVM commands configured
/// with the provided dependencies (or sensible defaults for testing).
///
/// This class centralizes test setup and ensures all commands use the correct
/// constructor signatures with Console parameter.
class TestPvmCommandRunner {
  final CommandRunner<int> runner;
  final MockConsole console;

  TestPvmCommandRunner({
    required IOSManager osManager,
    IProcessManager? processManager,
    PhpVersionManager? phpVersionManager,
    GitIgnoreService? gitIgnoreService,
    PhpExecutor? phpExecutor,
  })  : console = MockConsole(),
        runner = _PvmTestCommandRunner('pvm', 'PHP Version Manager') {
    // Create default implementations if not provided
    final phpVerMgr = phpVersionManager ?? PhpVersionManager(console);
    final gitIgnore = gitIgnoreService ?? GitIgnoreService(osManager, console);
    final phpExec = phpExecutor ??
        PhpExecutor(
          processManager: processManager ?? IOProcessManager(),
          osManager: osManager,
        );

    // Add all commands with correct constructor signatures
    runner.addCommand(UseCommand(
      osManager,
      phpVerMgr,
      gitIgnore,
      console,
    ));
    runner.addCommand(GlobalCommand(osManager, console));
    runner.addCommand(ListCommand(osManager, console));
    runner.addCommand(PhpCommand(phpExec, osManager, console));
    runner.addCommand(ComposerCommand(phpExec, osManager, console));
    runner.addCommand(VersionFlag(console));
  }

  /// Runs the command runner with the given arguments.
  /// Returns the exit code.
  Future<int> run(List<String> args) async {
    if (args.isNotEmpty && (args.first == '--version' || args.first == '-v')) {
      print('PVM version: 1.0.0');
      return 0;
    }
    return await runner.run(args) ?? 0;
  }

  /// Convenience method to run a command and capture output via zone.
  /// Returns the exit code and populates the [capturedOutput] list.
  Future<int> runAndCapture(
    List<String> args, {
    List<String>? capturedOutput,
  }) async {
    final output = capturedOutput ?? <String>[];

    // Intercept global version flag
    if (args.isNotEmpty && (args.first == '--version' || args.first == '-v')) {
      output.add('PVM version: 1.0.0');
      return 0;
    }

    return await runZoned(() async {
      return await runner.run(args) ?? 0;
    }, zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        output.add(line);
      },
    ));
  }
}

/// Fake implementation of [PhpVersionManager] for testing.
/// Overrides methods to return controllable values.
class FakePhpVersionManager extends PhpVersionManager {
  PhpVersion? readResult;
  String? writeVersion;
  String? writeRootPath;
  bool promptMismatchResult = true;
  PhpVersion? promptVersionPickResult;
  bool readLastUsedVersionCalled = false;

  FakePhpVersionManager(Console console) : super(console);

  @override
  Future<PhpVersion?> readLastUsedVersion({required String rootPath}) async {
    readLastUsedVersionCalled = true;
    return readResult;
  }

  @override
  Future<void> writeCurrentVersion({
    required String rootPath,
    required PhpVersion version,
  }) async {
    writeRootPath = rootPath;
    writeVersion = version.toString();
  }

  @override
  Future<bool> promptMismatch({
    required PhpVersion currentVersion,
    required PhpVersion requestedVersion,
  }) async {
    return promptMismatchResult;
  }

  @override
  Future<PhpVersion?> promptVersionPick({
    required List<PhpVersion> availableVersions,
  }) async {
    return promptVersionPickResult;
  }
}

/// Fake implementation of [GitIgnoreService] for testing.
/// Records calls to verify behavior.
class FakeGitIgnoreService extends GitIgnoreService {
  bool ensureGitignoreCalled = false;
  bool ensureGitignoreResult = true;
  bool ensurePvmSymlinkCalled = false;
  bool ensurePvmSymlinkResult = true;

  FakeGitIgnoreService(IOSManager osManager, Console console)
      : super(osManager, console);

  @override
  Future<bool> ensureGitignoreIncludesPvm({required String rootPath}) async {
    ensureGitignoreCalled = true;
    return ensureGitignoreResult;
  }

  @override
  Future<bool> ensurePvmSymlinkExists({
    required String symlinkPath,
    required String targetPath,
  }) async {
    ensurePvmSymlinkCalled = true;
    return ensurePvmSymlinkResult;
  }
}
