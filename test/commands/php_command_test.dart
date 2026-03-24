import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import '../../lib/src/commands/php_command.dart';
import '../../lib/src/core/process_manager.dart';
import '../../lib/src/managers/mock_os_manager.dart';
import '../../lib/src/services/php_executor.dart';

class RecordingProcessManager implements IProcessManager {
  ProcessSpec? lastInteractiveSpec;
  int runInteractiveCallCount = 0;
  int runCapturedCallCount = 0;
  int exitCodeToReturn;
  Object? interactiveErrorToThrow;

  RecordingProcessManager({
    this.exitCodeToReturn = 0,
    this.interactiveErrorToThrow,
  });

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    runInteractiveCallCount++;
    lastInteractiveSpec = spec;
    if (interactiveErrorToThrow != null) {
      throw interactiveErrorToThrow!;
    }
    return exitCodeToReturn;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) {
    runCapturedCallCount++;
    throw UnimplementedError();
  }
}

Future<int> executePhpCommand({
  required MockOSManager osManager,
  required RecordingProcessManager processManager,
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

/// Creates a temp directory with .php-version, .pvm subdir, and optionally php.exe.
Future<Directory> setupProjectDir({
  required String version,
  bool includePhpExe = true,
}) async {
  final dir = await Directory.systemTemp.createTemp('pvm-php-test-');
  await File('${dir.path}\\.php-version').writeAsString('$version\n');
  await Directory('${dir.path}\\.pvm').create();
  if (includePhpExe) {
    await File('${dir.path}\\.pvm\\php.exe').create();
  }
  return dir;
}

void main() {
  group('PhpCommand characterization tests', () {
    late MockOSManager osManager;
    late RecordingProcessManager processManager;
    late Directory tempDir;

    setUp(() {
      osManager = MockOSManager();
      processManager = RecordingProcessManager();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('php command forwards resolved executable and args unchanged',
        () async {
      tempDir = await setupProjectDir(version: '8.2');
      osManager.mockCurrentDirectory = tempDir.path;

      final forwardedArgs = [
        '--version',
        '-d',
        'memory_limit=256M',
        'artisan',
        'migrate',
        '--force',
      ];

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
        args: forwardedArgs,
      );

      expect(exitCode, equals(0));
      expect(processManager.runInteractiveCallCount, equals(1));
      expect(processManager.lastInteractiveSpec?.executable,
          endsWith(r'\.pvm\php.exe'));
      expect(processManager.lastInteractiveSpec?.arguments,
          orderedEquals(forwardedArgs));
      expect(processManager.lastInteractiveSpec?.workingDirectory,
          equals(tempDir.path));
    });

    test('php command returns child exit code unchanged', () async {
      tempDir = await setupProjectDir(version: '8.2');
      osManager.mockCurrentDirectory = tempDir.path;
      processManager = RecordingProcessManager(exitCodeToReturn: 73);

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
      );

      expect(exitCode, equals(73));
      expect(processManager.runInteractiveCallCount, equals(1));
      expect(processManager.runCapturedCallCount, equals(0));
    });

    test('php command handles local path containing spaces', () async {
      tempDir = await Directory.systemTemp.createTemp('pvm php test spaces-');
      await File('${tempDir.path}\\.php-version').writeAsString('8.2\n');
      await Directory('${tempDir.path}\\.pvm').create();
      await File('${tempDir.path}\\.pvm\\php.exe').create();

      osManager.mockCurrentDirectory = tempDir.path;

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
        args: const ['-v'],
      );

      expect(exitCode, equals(0));
      expect(processManager.lastInteractiveSpec?.executable,
          endsWith(r'\.pvm\php.exe'));
      expect(
          processManager.lastInteractiveSpec?.arguments, orderedEquals(['-v']));
      expect(processManager.runCapturedCallCount, equals(0));
    });

    test('php command forwards very long argument unchanged', () async {
      tempDir = await setupProjectDir(version: '8.2');
      osManager.mockCurrentDirectory = tempDir.path;

      final longArg = 'x' * 10000;

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
        args: [longArg],
      );

      expect(exitCode, equals(0));
      expect(processManager.lastInteractiveSpec?.executable,
          endsWith(r'\.pvm\php.exe'));
      expect(processManager.lastInteractiveSpec?.arguments, hasLength(1));
      expect(processManager.lastInteractiveSpec?.arguments.first, longArg);
      expect(processManager.runCapturedCallCount, equals(0));
    });

    test('php command returns 1 when interactive process start fails',
        () async {
      tempDir = await setupProjectDir(version: '8.2');
      osManager.mockCurrentDirectory = tempDir.path;

      processManager = RecordingProcessManager(
        interactiveErrorToThrow: Exception('process start failed'),
      );

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
        args: const ['artisan', 'serve'],
      );

      expect(exitCode, equals(1));
      expect(processManager.runInteractiveCallCount, equals(1));
      expect(processManager.runCapturedCallCount, equals(0));
    });

    test('php command returns 1 when local .pvm directory is missing',
        () async {
      // CWD has no .php-version and no .pvm — PhpCommand should return 1
      tempDir = await Directory.systemTemp.createTemp('pvm-php-missing-');
      osManager.mockCurrentDirectory = tempDir.path;
      // Mock: .pvm directory does not exist
      osManager.setDirectoryExistsResult('${tempDir.path}\\.pvm', false);
      // No .php-version, no .pvm

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
      );

      expect(exitCode, equals(1));
      expect(processManager.runInteractiveCallCount, equals(0));
    });

    test('php command returns 1 when resolved php executable is missing',
        () async {
      tempDir = await setupProjectDir(version: '8.2', includePhpExe: false);
      osManager.mockCurrentDirectory = tempDir.path;

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
      );

      expect(exitCode, equals(1));
      expect(processManager.runInteractiveCallCount, equals(0));
    });
  });
}
