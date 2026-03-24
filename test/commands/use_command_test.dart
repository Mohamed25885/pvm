import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import '../../lib/src/commands/use_command.dart';
import '../../lib/src/core/gitignore_service.dart';
import '../../lib/src/core/php_version_manager.dart';
import '../../lib/src/managers/mock_os_manager.dart';

/// FakePhpVersionManager records calls and returns canned values for testing.
class FakePhpVersionManager extends PhpVersionManager {
  String? readResult;
  String? writeVersion;
  String? writeRootPath;
  bool promptMismatchResult = true;
  String? promptVersionPickResult;
  bool readLastUsedVersionCalled = false;

  @override
  Future<String?> readLastUsedVersion({required String rootPath}) async {
    readLastUsedVersionCalled = true;
    return readResult;
  }

  @override
  Future<void> writeCurrentVersion({
    required String rootPath,
    required String version,
  }) async {
    writeRootPath = rootPath;
    writeVersion = version;
  }

  @override
  Future<bool> promptMismatch({
    required String currentVersion,
    required String requestedVersion,
  }) async {
    return promptMismatchResult;
  }

  @override
  Future<String?> promptVersionPick({
    required List<String> availableVersions,
  }) async {
    return promptVersionPickResult;
  }
}

/// FakeGitIgnoreService records calls.
class FakeGitIgnoreService extends GitIgnoreService {
  bool ensureGitignoreCalled = false;
  bool ensureGitignoreResult = true;
  bool ensurePvmSymlinkCalled = false;
  bool ensurePvmSymlinkResult = true;

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

Future<int> _runUseCommand({
  required MockOSManager osManager,
  required FakePhpVersionManager phpVersionManager,
  required FakeGitIgnoreService gitIgnoreService,
  List<String> args = const [],
}) async {
  final runner = CommandRunner<int>('test', 'test');
  runner.addCommand(UseCommand(osManager, phpVersionManager, gitIgnoreService));

  final result = await runner.run(['use', ...args]);
  return result ?? 1;
}

void main() {
  group('UseCommand - no-arg behavior', () {
    test('returns error when no version and no .php-version exists', () async {
      final osManager = MockOSManager();
      final phpVer = FakePhpVersionManager();
      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
      );

      expect(exitCode, equals(1));
      expect(phpVer.readLastUsedVersionCalled, isTrue);
    });

    test('uses version from .php-version when no arg given', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride = true;

      final phpVer = FakePhpVersionManager();
      phpVer.readResult = '8.0';

      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
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

      final phpVer = FakePhpVersionManager();
      phpVer.readResult = null; // no .php-version

      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        args: ['8.2'],
      );

      expect(exitCode, equals(0));
      expect(phpVer.writeVersion, equals('8.2'));
    });

    test('invalid version format returns error', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];

      final phpVer = FakePhpVersionManager();
      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        args: ['invalid'],
      );

      expect(exitCode, equals(1));
    });

    test('non-existent version prompts user to pick', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.symlinkSourceExistsOverride = true;

      final phpVer = FakePhpVersionManager();
      phpVer.promptVersionPickResult = '8.0';

      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        args: ['9.0'],
      );

      expect(exitCode, equals(0));
      expect(phpVer.writeVersion, equals('8.0'));
    });

    test('non-existent version with no pick returns error', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0', '8.2'];

      final phpVer = FakePhpVersionManager();
      phpVer.promptVersionPickResult = null; // user cancelled

      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        args: ['9.0'],
      );

      expect(exitCode, equals(1));
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

      final phpVer = FakePhpVersionManager();
      phpVer.readResult = '8.0'; // .php-version has 8.0

      final gitIgnore = FakeGitIgnoreService();

      // Non-interactive: stdout has no terminal (promptMismatch returns false)
      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        args: ['8.2'],
      );

      expect(exitCode, equals(0));
      // In non-interactive mode, .php-version is NOT updated
      expect(phpVer.writeVersion, isNull);
    });
  });

  group('UseCommand - GitIgnoreService auto-run', () {
    test('runs GitIgnoreService on every use', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0'];
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride = true;

      final phpVer = FakePhpVersionManager();
      phpVer.readResult = null;

      final gitIgnore = FakeGitIgnoreService();

      await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        args: ['8.0'],
      );

      expect(gitIgnore.ensureGitignoreCalled, isTrue);
      expect(gitIgnore.ensurePvmSymlinkCalled, isTrue);
    });
  });

  group('UseCommand - rootPath discovery', () {
    test('uses CWD when no .php-version is found up the tree', () async {
      final osManager = MockOSManager();
      osManager.mockVersions = ['8.0'];
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.symlinkSourceExistsOverride = true;

      final phpVer = FakePhpVersionManager();
      phpVer.readResult = null;

      final gitIgnore = FakeGitIgnoreService();

      await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        args: ['8.0'],
      );

      // Should still call GitIgnoreService (even if .php-version not found)
      expect(gitIgnore.ensureGitignoreCalled, isTrue);
    });
  });
}
