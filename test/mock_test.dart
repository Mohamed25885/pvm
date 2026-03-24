import 'package:test/test.dart';

import '../lib/src/core/process_manager.dart';
import '../lib/src/managers/mock_os_manager.dart';

void main() {
  group('IOSManager Interface Tests', () {
    late MockOSManager osManager;

    setUp(() {
      osManager = MockOSManager();
    });

    test('getAvailableVersions returns mock versions', () {
      final versions = osManager.getAvailableVersions('/mock/versions');
      expect(versions, equals(['8.0', '8.2']));
    });

    test('getProgramDirectory returns mock path', () {
      expect(osManager.programDirectory, equals('/mock/pvm'));
    });

    test('getLocalPath returns mock path', () {
      expect(osManager.localPath, equals('/mock/project/.pvm'));
    });

    test('getHomeDirectory returns mock home', () {
      expect(osManager.getHomeDirectory(), equals('/mock/home'));
    });

    test('createSymLink returns correct tuple', () async {
      osManager.symlinkSourceExistsOverride = true;
      final result = await osManager.createSymLink('8.0', '/source', '/target');
      expect(result.from, equals('/source'));
      expect(result.to, equals('/target'));
    });

    test('createSymLink throws when shouldThrowOnSymlink is true', () async {
      osManager.shouldThrowOnSymlink = true;
      expect(
        () => osManager.createSymLink('8.0', '/source', '/target'),
        throwsException,
      );
    });

    test('directoryExists returns false by default for non-mock paths',
        () async {
      // Without override or cache, non-mock paths check real filesystem
      expect(
          await osManager.directoryExists('/some/nonexistent/path'), isFalse);
    });

    test('directoryExists uses cache when set', () async {
      osManager.setDirectoryExistsResult('/some/path', true);
      expect(await osManager.directoryExists('/some/path'), isTrue);
    });

    test('directoryExists returns true with symlinkSourceExistsOverride',
        () async {
      osManager.symlinkSourceExistsOverride = true;
      expect(await osManager.directoryExists('/any/path'), isTrue);
    });

    test('fileExists returns false by default for non-mock paths', () async {
      // Without override or cache, non-mock paths check real filesystem
      expect(await osManager.fileExists('/some/nonexistent/path'), isFalse);
    });

    test('fileExists uses cache when set', () async {
      osManager.setFileExistsResult('/some/path', true);
      expect(await osManager.fileExists('/some/path'), isTrue);
    });
  });

  group('IProcessManager Interface Tests', () {
    late MockProcessManager processManager;

    setUp(() {
      processManager = MockProcessManager();
    });

    test('runInteractive returns mock exit code', () async {
      final exitCode = await processManager.runInteractive(
        ProcessSpec(executable: '/path/to/php', arguments: ['--version']),
      );
      expect(exitCode, equals(0));
    });

    test('runInteractive throws when shouldThrowOnRunInteractive is true',
        () async {
      processManager.shouldThrowOnRunInteractive = true;
      expect(
        () => processManager.runInteractive(
          ProcessSpec(executable: '/path/to/php', arguments: ['--version']),
        ),
        throwsException,
      );
    });

    test('runCaptured returns captured stdout, stderr, and exit code',
        () async {
      processManager.mockStdout = 'php 8.4.1';
      processManager.mockStderr = '';

      final result = await processManager.runCaptured(
        ProcessSpec(executable: '/path/to/php', arguments: ['--version']),
      );

      expect(result.stdout, equals('php 8.4.1'));
      expect(result.stderr, equals(''));
      expect(result.exitCode, equals(0));
    });

    test('runCaptured throws when shouldThrowOnRunCaptured is true', () async {
      processManager.shouldThrowOnRunCaptured = true;
      expect(
        () => processManager.runCaptured(
          ProcessSpec(executable: '/path/to/php', arguments: ['--version']),
        ),
        throwsException,
      );
    });
  });
}
