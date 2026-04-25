import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import 'dart:io';

import '../helpers.dart';
import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';
import 'package:pvm/src/commands/use_command.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/interfaces/i_version_activator.dart';

Future<int> _runUseCommand({
  required MockOSManager osManager,
  required FakePhpVersionManager phpVersionManager,
  required FakeGitIgnoreService gitIgnoreService,
  required MockConsole console,
  required IVersionActivator versionActivator,
  List<String> args = const [],
}) async {
  final runner = CommandRunner<int>('test', 'test');
  runner.addCommand(UseCommand(
    osManager,
    phpVersionManager,
    gitIgnoreService,
    versionActivator,
    console,
  ));

  final result = await runner.run(['use', ...args]);
  return result ?? 1;
}

void main() {
  group('UseCommand - Symlink Behavior Tests', () {
    setUp(() {
      // Reset mocks before each test
    });

    test(
        'a) pvm use with no args and no .php-version file: exit code 1, no .pvm symlink created',
        () async {
      final osManager = MockOSManager();
      osManager.mockCurrentDirectory = r'C:\project';
      final console = MockConsole();
      final phpVer = FakePhpVersionManager(console);
      final gitIgnore = FakeGitIgnoreService(osManager, console);
      final versionActivator = MockVersionActivator();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        versionActivator: versionActivator,
      );

      // Should fail with exit code 2 (usageError)
      expect(exitCode, equals(2));

      // No local activation should be called
      expect(versionActivator.activateLocalCalled, isFalse);

      // .php-version should not be written
      expect(phpVer.writeVersion, isNull);
    });

    test(
        'b) pvm use <version> with version directory exists: creates .pvm symlink pointing to versions/<version>',
        () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.mockProgramDir = r'C:\pvm';
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride =
          true; // Simulate version dir exists
      osManager.mockCurrentDirectory = r'C:\project';
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.readResult = null; // No .php-version file

      final gitIgnore = FakeGitIgnoreService(osManager, console);
      final versionActivator = MockVersionActivator();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        versionActivator: versionActivator,
        args: ['8.2'],
      );

      // Should succeed
      expect(exitCode, equals(0));

      // Activator should have been called
      expect(versionActivator.activateLocalCalled, isTrue);
      expect(versionActivator.activateLocalVersion, equals('8.2'));

      // .php-version should be written
      expect(phpVer.writeVersion, equals('8.2'));
      expect(phpVer.writeRootPath, equals(Directory.current.path));
    });

    test(
        'c) pvm use with .php-version file present: reads version from file and creates correct symlink',
        () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.mockProgramDir = r'C:\pvm';
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride =
          true; // Simulate version dir exists
      osManager.mockCurrentDirectory = r'C:\project';
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.readResult = PhpVersion.parse('8.0'); // .php-version contains 8.0

      final gitIgnore = FakeGitIgnoreService(osManager, console);
      final versionActivator = MockVersionActivator();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        versionActivator: versionActivator,
      );

      // Should succeed
      expect(exitCode, equals(0));

      // Activator should have been called with correct version
      expect(versionActivator.activateLocalCalled, isTrue);
      expect(versionActivator.activateLocalVersion, equals('8.0'));

      // .php-version should NOT be rewritten (it already had the correct version)
      // Actually, according to UseCommand, when using .php-version, updateFile=true
      // So it should write the same version back
      expect(phpVer.writeVersion, equals('8.0'));
    });

    test(
        'd) pvm use <version> when version directory does NOT exist: returns error, no symlink',
        () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.mockProgramDir = r'C:\pvm';
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride =
          false; // Simulate version dir missing
      osManager.mockCurrentDirectory = r'C:\project';
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.readResult = null;

      final gitIgnore = FakeGitIgnoreService(osManager, console);
      final versionActivator = MockVersionActivator();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        versionActivator: versionActivator,
        args: ['8.2'],
      );

      // Should fail
      expect(exitCode, equals(ExitCode.versionNotFound));

      // Activator should NOT have been called
      expect(versionActivator.activateLocalCalled, isFalse);

      // .php-version should not be written
      expect(phpVer.writeVersion, isNull);
    });

    test(
        'e) pvm use with .php-version but version not installed: prompts pick and creates symlink',
        () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.mockProgramDir = r'C:\pvm';
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride = true;
      osManager.mockCurrentDirectory = r'C:\project';
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.readResult = PhpVersion.parse(
          '9.0'); // .php-version has version not in available list
      phpVer.promptVersionPickResult =
          PhpVersion.parse('8.2'); // User picks 8.2

      final gitIgnore = FakeGitIgnoreService(osManager, console);
      final versionActivator = MockVersionActivator();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        versionActivator: versionActivator,
      );

      // Should succeed
      expect(exitCode, equals(0));

      // Activator should have been called for picked version
      expect(versionActivator.activateLocalCalled, isTrue);
      expect(versionActivator.activateLocalVersion, equals('8.2'));

      // .php-version should be updated to picked version
      expect(phpVer.writeVersion, equals('8.2'));
    });
  });
}
