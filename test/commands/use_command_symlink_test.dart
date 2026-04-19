import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import 'dart:io';
import 'package:path/path.dart' as p;

import '../helpers.dart';
import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';
import '../../lib/src/commands/use_command.dart';
import '../../lib/src/core/exit_codes.dart';
import '../../lib/src/domain/php_version.dart';

Future<int> _runUseCommand({
  required MockOSManager osManager,
  required FakePhpVersionManager phpVersionManager,
  required FakeGitIgnoreService gitIgnoreService,
  required MockConsole console,
  List<String> args = const [],
}) async {
  final runner = CommandRunner<int>('test', 'test');
  runner.addCommand(UseCommand(
    osManager,
    phpVersionManager,
    gitIgnoreService,
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
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride = true;
      osManager.mockCurrentDirectory = r'C:\project';
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.readResult = null; // No .php-version file

      final gitIgnore = FakeGitIgnoreService(osManager, console);

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
      );

      // Should fail with exit code 1
      expect(exitCode, equals(ExitCode.usageError));

      // No symlink should be created
      expect(osManager.createdSymlinks, isEmpty);

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

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        args: ['8.2'],
      );

      // Should succeed
      expect(exitCode, equals(0));

      // Exactly one symlink should be created
      expect(osManager.createdSymlinks, hasLength(1));

      final symlink = osManager.createdSymlinks.first;
      // Symlink should be created at project root .pvm
      expect(symlink.to, equals(p.join(Directory.current.path, '.pvm')));
      // Symlink should point to the version directory in versions/
      expect(symlink.from, equals(r'C:\pvm\versions\8.2'));
      // Version should be recorded
      expect(symlink.version, equals('8.2'));

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

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
      );

      // Should succeed
      expect(exitCode, equals(0));

      // Exactly one symlink should be created
      expect(osManager.createdSymlinks, hasLength(1));

      final symlink = osManager.createdSymlinks.first;
      // Symlink should point to 8.0 version
      expect(symlink.from, equals(r'C:\pvm\versions\8.0'));
      expect(symlink.to, equals(p.join(Directory.current.path, '.pvm')));
      expect(symlink.version, equals('8.0'));

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

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        args: ['8.2'],
      );

      // Should fail
      expect(exitCode, equals(ExitCode.versionNotFound));

      // No symlink should be created
      expect(osManager.createdSymlinks, isEmpty);

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

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
      );

      // Should succeed
      expect(exitCode, equals(0));

      // Symlink should be created for picked version
      expect(osManager.createdSymlinks, hasLength(1));
      expect(osManager.createdSymlinks.first.version, equals('8.2'));
      expect(
          osManager.createdSymlinks.first.from, equals(r'C:\pvm\versions\8.2'));

      // .php-version should be updated to picked version
      expect(phpVer.writeVersion, equals('8.2'));
    });
  });
}
