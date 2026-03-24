import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import '../../lib/src/commands/php_command.dart';
import '../../lib/src/core/process_manager.dart';
import '../../lib/src/managers/mock_os_manager.dart';

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
  final runner = CommandRunner<int>('test', 'test');
  runner.addCommand(PhpCommand(osManager, processManager));

  final result = await runner.run(['php', ...args]);
  return result ?? 0;
}

void main() {
  group('PhpCommand characterization tests', () {
    late MockOSManager osManager;
    late RecordingProcessManager processManager;

    setUp(() {
      osManager = MockOSManager();
      processManager = RecordingProcessManager();
    });

    test('php command forwards resolved executable and args unchanged',
        () async {
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.setDirectoryExistsResult(osManager.localPath, true);

      final expectedPhpExe = '${osManager.localPath}\\php.exe';
      osManager.setFileExistsResult(expectedPhpExe, true);

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
          equals(expectedPhpExe));
      expect(processManager.lastInteractiveSpec?.executable,
          endsWith(r'\php.exe'));
      expect(processManager.lastInteractiveSpec?.arguments,
          orderedEquals(forwardedArgs));
    });

    test('php command returns child exit code unchanged', () async {
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.setDirectoryExistsResult(osManager.localPath, true);

      final expectedPhpExe = '${osManager.localPath}\\php.exe';
      osManager.setFileExistsResult(expectedPhpExe, true);
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
      osManager.mockLocalPath = r'C:\Program Files\My Project\.pvm';
      osManager.setDirectoryExistsResult(osManager.localPath, true);

      final expectedPhpExe = '${osManager.localPath}\\php.exe';
      osManager.setFileExistsResult(expectedPhpExe, true);

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
        args: const ['-v'],
      );

      expect(exitCode, equals(0));
      expect(processManager.lastInteractiveSpec?.executable,
          equals(expectedPhpExe));
      expect(
          processManager.lastInteractiveSpec?.arguments, orderedEquals(['-v']));
      expect(processManager.runCapturedCallCount, equals(0));
    });

    test('php command forwards very long argument unchanged', () async {
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.setDirectoryExistsResult(osManager.localPath, true);

      final expectedPhpExe = '${osManager.localPath}\\php.exe';
      osManager.setFileExistsResult(expectedPhpExe, true);

      final longArg = 'x' * 10000;

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
        args: [longArg],
      );

      expect(exitCode, equals(0));
      expect(processManager.lastInteractiveSpec?.executable,
          equals(expectedPhpExe));
      expect(processManager.lastInteractiveSpec?.arguments, hasLength(1));
      expect(processManager.lastInteractiveSpec?.arguments.first, longArg);
      expect(processManager.runCapturedCallCount, equals(0));
    });

    test('php command returns 1 when interactive process start fails',
        () async {
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.setDirectoryExistsResult(osManager.localPath, true);

      final expectedPhpExe = '${osManager.localPath}\\php.exe';
      osManager.setFileExistsResult(expectedPhpExe, true);

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

    test('php command returns 1 when local version directory is missing',
        () async {
      osManager.mockLocalPath = r'C:\missing\.pvm';
      osManager.setDirectoryExistsResult(osManager.localPath, false);

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
      );

      expect(exitCode, equals(1));
      expect(processManager.runInteractiveCallCount, equals(0));
    });

    test('php command returns 1 when resolved php executable is missing',
        () async {
      osManager.mockLocalPath = r'C:\project\.pvm';
      osManager.setDirectoryExistsResult(osManager.localPath, true);

      final expectedPhpExe = '${osManager.localPath}\\php.exe';
      osManager.setFileExistsResult(expectedPhpExe, false);

      final exitCode = await executePhpCommand(
        osManager: osManager,
        processManager: processManager,
      );

      expect(exitCode, equals(1));
      expect(processManager.runInteractiveCallCount, equals(0));
    });
  });
}
