import 'package:args/command_runner.dart';
import 'package:test/test.dart';

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
  group('UseCommand - no-arg behavior', () {
    test('returns error when no version and no .php-version exists', () async {
      final osManager = MockOSManager();
      final console = MockConsole();
      final phpVer = FakePhpVersionManager(console);
      final gitIgnore = FakeGitIgnoreService(osManager, console);

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
      );

      expect(exitCode, equals(ExitCode.usageError));
      expect(phpVer.readLastUsedVersionCalled, isTrue);
    });

    test('uses version from .php-version when no arg given', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride = true;
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.readResult = PhpVersion.parse('8.0');

      final gitIgnore = FakeGitIgnoreService(osManager, console);

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
      );

      expect(exitCode, equals(0));
      expect(phpVer.writeVersion, equals('8.0'));
    });
  });

  group('UseCommand - version argument', () {
    test('valid version creates symlink and updates .php-version', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride = true;
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.readResult = null; // no .php-version

      final gitIgnore = FakeGitIgnoreService(osManager, console);

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        args: ['8.2'],
      );

      expect(exitCode, equals(0));
      expect(phpVer.writeVersion, equals('8.2'));
    });

    test('invalid version format returns error', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      final gitIgnore = FakeGitIgnoreService(osManager, console);

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        args: ['invalid'],
      );

      expect(exitCode, equals(ExitCode.usageError));
    });

    test('non-existent version prompts user to pick', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.symlinkSourceExistsOverride = true;
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.promptVersionPickResult = PhpVersion.parse('8.0');

      final gitIgnore = FakeGitIgnoreService(osManager, console);

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        args: ['9.0'],
      );

      expect(exitCode, equals(0));
      expect(phpVer.writeVersion, equals('8.0'));
    });

    test('non-existent version with no pick returns error', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.promptVersionPickResult = null; // user cancelled

      final gitIgnore = FakeGitIgnoreService(osManager, console);

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        args: ['9.0'],
      );

      expect(exitCode, equals(ExitCode.userCancelled));
    });
  });

  group('UseCommand - mismatch behavior (non-interactive)', () {
    test(
        'mismatch with non-interactive auto-applies without updating .php-version',
        () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride = true;
      final console = MockConsole();
      console.hasTerminal = false; // Simulate non-interactive

      final phpVer = FakePhpVersionManager(console);
      phpVer.readResult = PhpVersion.parse('8.0'); // .php-version has 8.0

      final gitIgnore = FakeGitIgnoreService(osManager, console);

      // Non-interactive: stdout has no terminal (promptMismatch returns false)
      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        args: ['8.2'],
      );

      expect(exitCode, equals(0));
      // Version is applied in non-interactive mode (symlink created), .php-version unchanged
      expect(phpVer.writeVersion, isNull);
    });
  });

  group('UseCommand - GitIgnoreService auto-run', () {
    test('runs GitIgnoreService on every use (but NOT early symlink creation)',
        () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0'];
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride = true;
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.readResult = null;

      final gitIgnore = FakeGitIgnoreService(osManager, console);

      await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        args: ['8.0'],
      );

      // Only ensureGitignoreIncludesPvm should be called early
      expect(gitIgnore.ensureGitignoreCalled, isTrue);
      // ensurePvmSymlinkExists should NOT be called early anymore
      expect(gitIgnore.ensurePvmSymlinkCalled, isFalse);
    });
  });

  group('UseCommand - rootPath discovery', () {
    test('uses CWD when no .php-version is found up the tree', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0'];
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride = true;
      final console = MockConsole();

      final phpVer = FakePhpVersionManager(console);
      phpVer.readResult = null;

      final gitIgnore = FakeGitIgnoreService(osManager, console);

      await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        console: console,
        args: ['8.0'],
      );

      // Should still call GitIgnoreService (even if .php-version not found)
      expect(gitIgnore.ensureGitignoreCalled, isTrue);
    });
  });
}
