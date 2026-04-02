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

      final phpVer = FakePhpVersionManager();
      phpVer.readResult = null; // No .php-version file

      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
      );

      // Should fail with exit code 1
      expect(exitCode, equals(1));

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

      final phpVer = FakePhpVersionManager();
      phpVer.readResult = null; // No .php-version file

      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        args: ['8.2'],
      );

      // Should succeed
      expect(exitCode, equals(0));

      // Exactly one symlink should be created
      expect(osManager.createdSymlinks, hasLength(1));

      final symlink = osManager.createdSymlinks.first;
      // Symlink should be created at project root .pvm
      expect(symlink.to, equals(r'C:\project\.pvm'));
      // Symlink should point to the version directory in versions/
      expect(symlink.from, equals(r'C:\pvm\versions\8.2'));
      // Version should be recorded
      expect(symlink.version, equals('8.2'));

      // .php-version should be written
      expect(phpVer.writeVersion, equals('8.2'));
      expect(phpVer.writeRootPath, equals(r'C:\project'));
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

      final phpVer = FakePhpVersionManager();
      phpVer.readResult = '8.0'; // .php-version contains 8.0

      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
      );

      // Should succeed
      expect(exitCode, equals(0));

      // Exactly one symlink should be created
      expect(osManager.createdSymlinks, hasLength(1));

      final symlink = osManager.createdSymlinks.first;
      // Symlink should point to 8.0 version
      expect(symlink.from, equals(r'C:\pvm\versions\8.0'));
      expect(symlink.to, equals(r'C:\project\.pvm'));
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

      final phpVer = FakePhpVersionManager();
      phpVer.readResult = null;

      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
        args: ['8.2'],
      );

      // Should fail
      expect(exitCode, equals(1));

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

      final phpVer = FakePhpVersionManager();
      phpVer.readResult =
          '9.0'; // .php-version has version not in available list
      phpVer.promptVersionPickResult = '8.2'; // User picks 8.2

      final gitIgnore = FakeGitIgnoreService();

      final exitCode = await _runUseCommand(
        osManager: osManager,
        phpVersionManager: phpVer,
        gitIgnoreService: gitIgnore,
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
