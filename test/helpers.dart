import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'package:pvm/src/commands/composer_command.dart';
import 'package:pvm/src/commands/global_command.dart';
import 'package:pvm/src/commands/list_command.dart';
import 'package:pvm/src/commands/php_command.dart';
import 'package:pvm/src/commands/use_command.dart';
import 'package:pvm/src/commands/version_flag.dart';
import 'package:pvm/src/core/console.dart';
import 'package:pvm/src/core/gitignore_service.dart';
import 'package:pvm/src/core/os_manager.dart';
import 'package:pvm/src/core/php_version_manager.dart';
import 'package:pvm/src/core/platform_constants.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/core/executable_resolver.dart';
import 'package:pvm/src/core/composer_locator.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/process/io_process_manager.dart';
import 'package:pvm/src/services/php_executor.dart';
import 'package:pvm/src/interfaces/i_version_activator.dart';
import 'services/fake_os_manager.dart';
import 'mocks/mock_console.dart';

/// Private CommandRunner subclass that enables trailing options.
class _PvmTestCommandRunner extends CommandRunner<int> {
  _PvmTestCommandRunner(String name, String description)
      : super(name, description);

  ArgParser? _parser;
  @override
  ArgParser get argParser => _parser ??= ArgParser(allowTrailingOptions: true);
}

class MockPlatformInfo extends PlatformInfo {
  @override
  String get osType => 'windows';

  @override
  String get pathSeparator => ';';

  @override
  String get executableExtension => '.exe';

  @override
  String get homeDirectoryKey => 'USERPROFILE';

  @override
  List<String> get composerCandidates =>
      ['composer.bat', 'composer.cmd', 'composer.phar'];
}

class MockComposerLocator implements IComposerLocator {
  @override
  Future<String?> findComposer(Map<String, String> environment) async => null;
}

class MockExecutableResolver implements IExecutableResolver {
  final IOSManager osManager;

  MockExecutableResolver({required this.osManager});

  @override
  String get phpExecutableName => 'php.exe';

  @override
  Future<String> resolvePhpExecutable(String projectPath) async {
    final phpExe =
        '$projectPath${Platform.pathSeparator}.pvm${Platform.pathSeparator}php.exe';

    if (!(await osManager.fileExists(phpExe))) {
      throw Exception('PHP executable not found at $phpExe');
    }

    return phpExe;
  }
}

class MockVersionActivator implements IVersionActivator {
  final IOSManager _osManager;
  bool activateGlobalCalled = false;
  String? activateGlobalVersion;
  bool activateLocalCalled = false;
  String? activateLocalVersion;

  MockVersionActivator(this._osManager);

  @override
  Future<void> activateGlobal(String version) async {
    activateGlobalCalled = true;
    activateGlobalVersion = version;
    // Simulate symlink creation to allow throwing
    await _osManager.createSymLink(version, '/mock/source', '/mock/link');
  }

  @override
  Future<void> activateLocal(String version) async {
    activateLocalCalled = true;
    activateLocalVersion = version;
    // Simulate symlink creation to allow throwing
    await _osManager.createSymLink(version, '/mock/source', '/mock/link');
  }
}

/// Test helper that creates a CommandRunner with all PVM commands configured
/// with the provided dependencies (or sensible defaults for testing).
///
/// This class centralizes test setup and ensures all commands use the correct
/// constructor signatures with Console parameter.
class TestPvmCommandRunner {
  final CommandRunner<int> runner;
  final MockConsole console;
  final IOSManager osManager;
  late final PhpExecutor phpExecutor;
  late final ComposerLocator composerLocator;

  TestPvmCommandRunner({
    required IOSManager osManager,
    IProcessManager? processManager,
    PhpVersionManager? phpVersionManager,
    GitIgnoreService? gitIgnoreService,
    PhpExecutor? phpExecutor,
  })  : console = MockConsole(),
        osManager = osManager,
        runner = _PvmTestCommandRunner('pvm', 'PHP Version Manager') {
    final platformInfo = MockPlatformInfo();
    final platformConstants = PlatformConstants(platformInfo);
    final exeResolver = MockExecutableResolver(osManager: osManager);

    // Create default implementations if not provided
    final phpVerMgr = phpVersionManager ?? PhpVersionManager(console);
    final gitIgnore = gitIgnoreService ?? GitIgnoreService(osManager, console);
    final defaultProcessManager = () {
      final envOSManager = FakeOSManager()..environment = Platform.environment;
      return IOProcessManager(osManager: envOSManager);
    }();

    phpExecutor = phpExecutor ??
        PhpExecutor(
          processManager: processManager ?? defaultProcessManager,
          osManager: osManager,
          executableResolver: exeResolver,
        );
    composerLocator = ComposerLocator(
      platformConstants: platformConstants,
      osManager: osManager,
    );

    // Add all commands with correct constructor signatures
    runner.addCommand(UseCommand(
      osManager,
      phpVerMgr,
      gitIgnore,
      MockVersionActivator(osManager),
      console,
    ));
    runner.addCommand(
        GlobalCommand(osManager, MockVersionActivator(osManager), console));
    runner.addCommand(ListCommand(osManager, console));
    runner.addCommand(PhpCommand(phpExecutor, osManager, console));
    runner.addCommand(ComposerCommand(
      phpExecutor,
      osManager,
      composerLocator,
      console,
    ));
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
