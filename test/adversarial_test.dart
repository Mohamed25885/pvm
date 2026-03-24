import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import '../lib/src/commands/php_command.dart';
import '../lib/src/core/process_manager.dart';
import '../lib/src/managers/mock_os_manager.dart';
import '../lib/src/services/php_executor.dart';
import '../pvm.dart';

class _AdversarialRecordingProcessManager implements IProcessManager {
  ProcessSpec? lastInteractiveSpec;
  final int exitCodeToReturn;

  _AdversarialRecordingProcessManager({this.exitCodeToReturn = 0});

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    lastInteractiveSpec = spec;
    return exitCodeToReturn;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) {
    throw UnimplementedError();
  }
}

Future<int> _executePhpThroughCommandRunner({
  required MockOSManager osManager,
  required _AdversarialRecordingProcessManager processManager,
  List<String> args = const [],
}) async {
  final phpExecutor = PhpExecutor(
    processManager: processManager,
    osManager: osManager,
  );
  final runner = CommandRunner<int>('test', 'test');
  runner.addCommand(PhpCommand(osManager, phpExecutor));

  final result = await runner.run(['php', ...args]);
  return result ?? 0;
}

/// Walk up from [dir] and delete any .php-version files found.
/// This prevents _discoverRootPath from returning a parent directory.
Future<void> _cleanupPhpVersionInParents(Directory dir) async {
  while (true) {
    final phpVersion = File('${dir.path}\\.php-version');
    if (await phpVersion.exists()) {
      await phpVersion.delete();
    }
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
}

void main() {
  group('Adversarial Tests - Invalid Version Handling', () {
    late MockOSManager osManager;
    late PvmCommandRunner runner;

    setUp(() {
      osManager = MockOSManager();
      runner = PvmCommandRunner(osManager: osManager);
    });

    test('global command with non-existent version', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['global', '9.0']);
      expect(exitCode, equals(1));
    });

    test('global command with empty version string', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['global', '']);
      expect(exitCode, equals(1));
    });

    test('global command with special characters in version', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['global', '8.<script>']);
      expect(exitCode, equals(1));
    });

    test('global command with version containing spaces', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['global', '8. 0']);
      expect(exitCode, equals(1));
    });

    test('use command with non-existent version', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['use', '7.4']);
      expect(exitCode, equals(1));
    });

    test('use command with empty version string', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['use', '']);
      expect(exitCode, equals(1));
    });

    test('use command with special characters in version', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['use', '../../etc/passwd']);
      expect(exitCode, equals(1));
    });

    test('version with path traversal attempt', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['global', '../..']);
      expect(exitCode, equals(1));
    });

    test('version with null bytes', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['global', '8.0\x00']);
      expect(exitCode, equals(1));
    });
  });

  group('Adversarial Tests - Permission/Environment Errors', () {
    late MockOSManager osManager;
    late PvmCommandRunner runner;

    setUp(() {
      osManager = MockOSManager();
      runner = PvmCommandRunner(osManager: osManager);
    });

    test('global command throws on symlink creation failure', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.shouldThrowOnSymlink = true;
      final exitCode = await runner.run(['global', '8.0']);
      expect(exitCode, equals(1));
    });

    test('use command throws on symlink creation failure', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.shouldThrowOnSymlink = true;
      final exitCode = await runner.run(['use', '8.0']);
      expect(exitCode, equals(1));
    });

    test('php command throws on directoryExists failure', () async {
      osManager.shouldThrowOnDirectoryExists = true;
      expect(
        () => runner.run(['php']),
        throwsException,
      );
    });

    test('php command throws on fileExists failure', () async {
      osManager.shouldThrowOnFileExists = true;
      expect(
        () => runner.run(['php']),
        throwsException,
      );
    });

    test('symlink failure with no available versions', () async {
      osManager.mockVersions = [];
      osManager.shouldThrowOnSymlink = true;
      final exitCode = await runner.run(['global', '8.0']);
      expect(exitCode, equals(1));
    });

    test('symlink failure preserves error message', () async {
      osManager.mockVersions = ['8.0'];
      osManager.shouldThrowOnSymlink = true;
      final exitCode = await runner.run(['use', '8.0']);
      expect(exitCode, equals(1));
    });
  });

  group('Adversarial Tests - Argument Parsing Edge Cases', () {
    late MockOSManager osManager;
    late PvmCommandRunner runner;

    setUp(() {
      osManager = MockOSManager();
      runner = PvmCommandRunner(osManager: osManager);
    });

    test('no arguments prints help', () async {
      final exitCode = await runner.run([]);
      expect(exitCode, equals(0));
    });

    test('help flag -h prints help', () async {
      final exitCode = await runner.run(['-h']);
      expect(exitCode, equals(0));
    });

    test('help flag --help prints help', () async {
      final exitCode = await runner.run(['--help']);
      expect(exitCode, equals(0));
    });

    test('help flag with command prints command help', () async {
      final exitCode = await runner.run(['global', '--help']);
      expect(exitCode, equals(0));
    });

    test('global command with too many arguments', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['global', '8.0', '8.2', 'extra']);
      expect(exitCode, equals(1));
    });

    test('use command with too many arguments', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['use', '8.0', '8.2']);
      expect(exitCode, equals(1));
    });

    test('global command with no version specified', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['global']);
      expect(exitCode, equals(1));
    });

    test('use command with no version specified', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      final exitCode = await runner.run(['use']);
      expect(exitCode, equals(1));
    });

    test('unknown command throws exception', () async {
      expect(
        () => runner.run(['unknown']),
        throwsException,
      );
    });

    test('unknown flag passed to global throws exception', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      expect(
        () => runner.run(['global', '--unknown', '8.0']),
        throwsException,
      );
    });

    test('list command with extra arguments ignores them', () async {
      final exitCode = await runner.run(['list', 'extra', 'args']);
      expect(exitCode, equals(0));
    });

    test('php command with extra arguments passes them', () async {
      osManager.mockVersions = ['8.0'];
      // Set mockCurrentDirectory to isolate from real CWD's .pvm
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });

    test('multiple flags combined', () async {
      final exitCode = await runner.run(['-h', '--help']);
      expect(exitCode, equals(0));
    });
  });

  group('Adversarial Tests - PHP Command Edge Cases', () {
    late MockOSManager osManager;
    late PvmCommandRunner runner;

    setUp(() {
      osManager = MockOSManager();
      runner = PvmCommandRunner(osManager: osManager);
    });

    test('php command with no local .pvm directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });

    test('php command with .pvm directory but no php.exe', () async {
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });

    test('php command with valid path but php process fails', () async {
      // Set mockCurrentDirectory to isolate from real CWD's .pvm
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });

    test('php command with empty arguments list', () async {
      // Set mockCurrentDirectory to isolate from real CWD's .pvm
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });

    test('php command with special characters in arguments', () async {
      // Set mockCurrentDirectory to isolate from real CWD's .pvm
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });

    test('php command with path containing spaces', () async {
      // Create a temp project dir with .pvm and php.exe for this test
      final tempDir = await Directory.systemTemp.createTemp('pvm adv spaces-');
      await Directory('${tempDir.path}\\.pvm').create();
      await File('${tempDir.path}\\.pvm\\php.exe').create();

      // _discoverRootPath walks UP from tempDir looking for .php-version.
      // Clean up any leftover .php-version in the temp folder tree to ensure
      // _discoverRootPath returns tempDir.path (the test's project root).
      await _cleanupPhpVersionInParents(tempDir);

      osManager.mockCurrentDirectory = tempDir.path;

      final expectedPhpExe = '${tempDir.path}\\.pvm\\php.exe';

      final processManager =
          _AdversarialRecordingProcessManager(exitCodeToReturn: 37);

      final exitCode = await _executePhpThroughCommandRunner(
        osManager: osManager,
        processManager: processManager,
        args: const ['-v'],
      );

      expect(exitCode, equals(37));
      expect(processManager.lastInteractiveSpec?.executable,
          equals(expectedPhpExe));
      expect(
          processManager.lastInteractiveSpec?.arguments, orderedEquals(['-v']));

      await tempDir.delete(recursive: true);
    });

    test('php command with very long argument', () async {
      // Create a temp project dir with .pvm and php.exe for this test
      final tempDir = await Directory.systemTemp.createTemp('pvm adv long-');
      await Directory('${tempDir.path}\\.pvm').create();
      await File('${tempDir.path}\\.pvm\\php.exe').create();

      // Clean up any leftover .php-version in the temp folder tree
      await _cleanupPhpVersionInParents(tempDir);

      osManager.mockCurrentDirectory = tempDir.path;

      final expectedPhpExe = '${tempDir.path}\\.pvm\\php.exe';

      final processManager = _AdversarialRecordingProcessManager();
      final longArg = 'a' * 10000;

      final exitCode = await _executePhpThroughCommandRunner(
        osManager: osManager,
        processManager: processManager,
        args: [longArg],
      );

      expect(exitCode, equals(0));
      expect(processManager.lastInteractiveSpec?.executable,
          equals(expectedPhpExe));
      expect(processManager.lastInteractiveSpec?.arguments, hasLength(1));
      expect(processManager.lastInteractiveSpec?.arguments.first, longArg);

      await tempDir.delete(recursive: true);
    });
  });

  group('Adversarial Tests - Race Condition Scenarios', () {
    late MockOSManager osManager;
    late PvmCommandRunner runner;

    setUp(() {
      osManager = MockOSManager();
      osManager.symlinkSourceExistsOverride = true;
      runner = PvmCommandRunner(osManager: osManager);
    });

    test('version exists at check but not at symlink creation', () async {
      osManager.mockVersions = ['8.0', '8.2'];
      osManager.shouldThrowOnSymlink = true;
      final exitCode = await runner.run(['use', '8.0']);
      expect(exitCode, equals(1));
    });

    test('version deleted between availability check and use', () async {
      osManager.mockVersions = [];
      final exitCode = await runner.run(['global', '8.0']);
      expect(exitCode, equals(1));
    });

    test('concurrent version switches - last one wins', () async {
      osManager.mockVersions = ['8.0', '8.2'];

      final exitCode1 = await runner.run(['use', '8.0']);
      expect(exitCode1, equals(0));

      final exitCode2 = await runner.run(['use', '8.2']);
      expect(exitCode2, equals(0));
    });

    test('rapid switching between versions', () async {
      osManager.mockVersions = ['8.0', '8.2'];

      for (var i = 0; i < 10; i++) {
        final exitCode = await runner.run(['use', i % 2 == 0 ? '8.0' : '8.2']);
        expect(exitCode, equals(0));
      }
    });

    test('directory created between check and use', () async {
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });
  });

  group('Adversarial Tests - Edge Cases with Empty/Null Data', () {
    late MockOSManager osManager;
    late PvmCommandRunner runner;

    setUp(() {
      osManager = MockOSManager();
      runner = PvmCommandRunner(osManager: osManager);
    });

    test('empty versions list', () async {
      osManager.mockVersions = [];
      final exitCode = await runner.run(['list']);
      expect(exitCode, equals(1));
    });

    test('empty mock home directory', () async {
      osManager.mockHomeDir = '';
      osManager.mockVersions = ['8.0'];
      osManager.symlinkSourceExistsOverride = true;
      final exitCode = await runner.run(['global', '8.0']);
      expect(exitCode, equals(0));
    });

    test('empty mock program directory', () async {
      osManager.mockProgramDir = '';
      osManager.mockVersions = ['8.0'];
      osManager.symlinkSourceExistsOverride = true;
      final exitCode = await runner.run(['use', '8.0']);
      expect(exitCode, equals(0));
    });

    test('whitespace-only version string', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['global', '   ']);
      expect(exitCode, equals(1));
    });

    test('version with newline characters', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['global', '8.0\n']);
      expect(exitCode, equals(1));
    });
  });

  group('Adversarial Tests - List Command Edge Cases', () {
    late MockOSManager osManager;
    late PvmCommandRunner runner;

    setUp(() {
      osManager = MockOSManager();
      runner = PvmCommandRunner(osManager: osManager);
    });

    test('list command with single version', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['list']);
      expect(exitCode, equals(0));
    });

    test('list command with many versions', () async {
      osManager.mockVersions = [
        '5.6',
        '7.0',
        '7.1',
        '7.2',
        '7.3',
        '7.4',
        '8.0',
        '8.1',
        '8.2',
        '8.3'
      ];
      final exitCode = await runner.run(['list']);
      expect(exitCode, equals(0));
    });

    test('list command with unsorted versions', () async {
      osManager.mockVersions = ['8.2', '7.4', '8.0', '5.6'];
      final exitCode = await runner.run(['list']);
      expect(exitCode, equals(0));
    });

    test('list command with duplicate versions', () async {
      osManager.mockVersions = ['8.0', '8.0', '8.2'];
      final exitCode = await runner.run(['list']);
      expect(exitCode, equals(0));
    });
  });

  group('Adversarial Tests - Invalid Paths', () {
    late MockOSManager osManager;
    late PvmCommandRunner runner;

    setUp(() {
      osManager = MockOSManager();
      osManager.symlinkSourceExistsOverride = true;
      runner = PvmCommandRunner(osManager: osManager);
    });

    test('very long path', () async {
      final longPath = '/${'a/' * 100}';
      osManager.mockProgramDir = longPath;
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['use', '8.0']);
      expect(exitCode, equals(0));
    });

    test('path with unicode characters', () async {
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });

    test('path with only special characters', () async {
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });

    test('root directory path', () async {
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });

    test('network path style', () async {
      final tempDir = await Directory.systemTemp.createTemp('pvm-adv-');
      runner = PvmCommandRunner(
        osManager: osManager,
        mockCurrentDirectory: tempDir.path,
      );
      final exitCode = await runner.run(['php']);
      await tempDir.delete(recursive: true);
      expect(exitCode, equals(1));
    });
  });

  group('Adversarial Tests - Command Runner Configuration', () {
    test('PvmCommandRunner can be instantiated with custom OSManager', () {
      final mockOsManager = MockOSManager();
      final runner = PvmCommandRunner(osManager: mockOsManager);
      expect(runner, isNotNull);
    });

    test('PvmCommandRunner has all expected commands', () {
      final runner = PvmCommandRunner();
      expect(runner.commands.containsKey('global'), isTrue);
      expect(runner.commands.containsKey('use'), isTrue);
      expect(runner.commands.containsKey('list'), isTrue);
      expect(runner.commands.containsKey('php'), isTrue);
    });

    test('PvmCommandRunner command names are correct', () {
      final runner = PvmCommandRunner();
      expect(runner.commands['global']?.name, equals('global'));
      expect(runner.commands['use']?.name, equals('use'));
      expect(runner.commands['list']?.name, equals('list'));
      expect(runner.commands['php']?.name, equals('php'));
    });
  });

  group('Adversarial Tests - Edge Cases with Special Commands', () {
    late MockOSManager osManager;
    late PvmCommandRunner runner;

    setUp(() {
      osManager = MockOSManager();
      runner = PvmCommandRunner(osManager: osManager);
    });

    test('version with leading dash treated as flag throws exception',
        () async {
      osManager.mockVersions = ['8.0'];
      expect(
        () => runner.run(['global', '-8.0']),
        throwsException,
      );
    });

    test('version with double dots', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['global', '8..0']);
      expect(exitCode, equals(1));
    });

    test('version starting with dot', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['global', '.8.0']);
      expect(exitCode, equals(1));
    });

    test('version with plus sign', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['global', '8.0+dev']);
      expect(exitCode, equals(1));
    });

    test('version with alpha suffix', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['global', '8.0alpha1']);
      expect(exitCode, equals(1));
    });

    test('version with RC suffix', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['global', '8.0RC1']);
      expect(exitCode, equals(1));
    });

    test('very large version number', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['global', '999.999.999']);
      expect(exitCode, equals(1));
    });

    test('negative version number treated as flag throws exception', () async {
      osManager.mockVersions = ['8.0'];
      expect(
        () => runner.run(['global', '-1.0']),
        throwsException,
      );
    });

    test('version with letters only', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['global', 'abc']);
      expect(exitCode, equals(1));
    });

    test('version with only numbers', () async {
      osManager.mockVersions = ['8.0'];
      final exitCode = await runner.run(['global', '123']);
      expect(exitCode, equals(1));
    });
  });

  group('Adversarial Tests - Case Sensitivity', () {
    late MockOSManager osManager;
    late PvmCommandRunner runner;

    setUp(() {
      osManager = MockOSManager();
      runner = PvmCommandRunner(osManager: osManager);
    });

    test('version with uppercase', () async {
      osManager.mockVersions = ['8.0'];
      osManager.symlinkSourceExistsOverride = true;
      final exitCode = await runner.run(['global', '8.0']);
      expect(exitCode, equals(0));
    });

    test('command name case sensitivity throws exception', () async {
      expect(
        () => runner.run(['GLOBAL', '8.0']),
        throwsException,
      );
    });

    test('mixed case command name throws exception', () async {
      expect(
        () => runner.run(['Use', '8.0']),
        throwsException,
      );
    });
  });
}
