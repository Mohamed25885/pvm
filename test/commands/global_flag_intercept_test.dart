import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import '../../pvm.dart';
import '../../lib/src/core/gitignore_service.dart';
import '../../lib/src/core/os_manager.dart';
import '../../lib/src/core/php_version_manager.dart';
import '../../lib/src/core/process_manager.dart';
import '../../lib/src/managers/mock_os_manager.dart';
import '../../lib/src/version.dart';

/// Helper class to capture print output and track exit code.
class PrintCapture {
  final List<String> lines = [];
  final List<String> errors = [];
  int? exitCode;

  void capturePrint(String message) {
    lines.add(message);
  }

  void captureError(String message) {
    errors.add(message);
  }

  String get output => lines.join('\n');
  String get errorOutput => errors.join('\n');
}

/// Custom ProcessManager that records calls for verification.
class RecordingProcessManager implements IProcessManager {
  ProcessSpec? lastInteractiveSpec;
  ProcessSpec? lastCapturedSpec;
  int runInteractiveCallCount = 0;
  int runCapturedCallCount = 0;
  int exitCodeToReturn;
  String? stdoutToReturn;
  String? stderrToReturn;

  RecordingProcessManager({
    this.exitCodeToReturn = 0,
    this.stdoutToReturn,
    this.stderrToReturn,
  });

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    runInteractiveCallCount++;
    lastInteractiveSpec = spec;
    return exitCodeToReturn;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    runCapturedCallCount++;
    lastCapturedSpec = spec;
    return CapturedProcessResult(
      exitCode: exitCodeToReturn,
      stdout: stdoutToReturn ?? '',
      stderr: stderrToReturn ?? '',
    );
  }
}

Future<int> runPvmCommandRunner({
  required List<String> args,
  required PrintCapture capture,
  IOSManager? osManager,
  IProcessManager? processManager,
  PhpVersionManager? phpVersionManager,
  GitIgnoreService? gitIgnoreService,
}) async {
  final runner = PvmCommandRunner(
    osManager: osManager,
    processManager: processManager,
    phpVersionManager: phpVersionManager,
    gitIgnoreService: gitIgnoreService,
  );

  // Use runZoned to capture print output
  return await runZoned(() async {
    final result = await runner.run(args);
    return result ?? 0;
  }, zoneSpecification: ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      capture.capturePrint(line);
    },
  ));
}

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
  group('Global flag intercept tests', () {
    late PrintCapture capture;
    late MockOSManager osManager;
    late RecordingProcessManager processManager;

    setUp(() {
      capture = PrintCapture();
      osManager = MockOSManager();
      processManager = RecordingProcessManager();
    });

    tearDown(() async {
      // Cleanup any temp directories if needed
    });

    test('pvm --version shows PVM version and exits 0', () async {
      final exitCode = await runPvmCommandRunner(
        args: ['--version'],
        capture: capture,
      );

      expect(exitCode, equals(0));
      expect(capture.output, contains('PVM version: $packageVersion'));
      expect(capture.output, isNot(contains('Usage:')));
    });

    test('pvm --help shows top-level help and exits 0', () async {
      final exitCode = await runPvmCommandRunner(
        args: ['--help'],
        capture: capture,
      );

      expect(exitCode, equals(0));
      expect(capture.output, contains('PHP Version Manager'));
      expect(capture.output, contains('Usage:'));
      expect(capture.output, contains('global'));
      expect(capture.output, contains('use'));
      expect(capture.output, contains('list'));
      expect(capture.output, contains('php'));
      expect(capture.output, contains('composer'));
    });

    test(
        'pvm php --version delegates to PhpCommand (does not show PVM version)',
        () async {
      // Setup: create a project directory with .php-version and .pvm/php.exe
      final tempDir = await setupProjectDir(version: '8.2');
      osManager.mockCurrentDirectory = tempDir.path;

      // Mock process manager to simulate PHP --version output
      processManager = RecordingProcessManager(
        exitCodeToReturn: 0,
        stdoutToReturn: 'PHP 8.2.0 (cli) ...',
      );

      final exitCode = await runPvmCommandRunner(
        args: ['php', '--version'],
        capture: capture,
        osManager: osManager,
        processManager: processManager,
      );

      // Verify delegation: exit code from PhpCommand (0)
      expect(exitCode, equals(0));

      // Verify that the process manager was called (PhpCommand executed)
      expect(processManager.runInteractiveCallCount, equals(1));
      expect(processManager.lastInteractiveSpec?.executable,
          endsWith(r'\.pvm\php.exe'));
      expect(processManager.lastInteractiveSpec?.arguments,
          orderedEquals(['--version']));

      // Verify PVM version was NOT printed
      expect(capture.output, isNot(contains('PVM version:')));
      // Note: Child process output not captured via print; verified via process call count/spec.
      // expect(capture.output, contains('PHP 8.2.0')); // removed - not capturable
    });

    test('pvm php --help delegates to PhpCommand help', () async {
      // Setup: create a project directory with .php-version and .pvm/php.exe
      final tempDir = await setupProjectDir(version: '8.2');
      osManager.mockCurrentDirectory = tempDir.path;

      // Mock process manager to simulate php --help output
      processManager = RecordingProcessManager(
        exitCodeToReturn: 0,
        stdoutToReturn: 'PHP Help output...',
      );

      final exitCode = await runPvmCommandRunner(
        args: ['php', '--help'],
        capture: capture,
        osManager: osManager,
        processManager: processManager,
      );

      // Verify delegation
      expect(exitCode, equals(0));

      // Verify that the process manager was called
      expect(processManager.runInteractiveCallCount, equals(1));
      expect(processManager.lastInteractiveSpec?.executable,
          endsWith(r'\.pvm\php.exe'));
      expect(processManager.lastInteractiveSpec?.arguments,
          orderedEquals(['--help']));

      // Verify PVM help was NOT printed
      expect(capture.output, isNot(contains('Usage:')));
      // Note: Child process output not captured via print; verified via process call.
      // expect(capture.output, contains('PHP Help output...')); // removed - not capturable
    });

    test('pvm --help with no args shows help', () async {
      final exitCode = await runPvmCommandRunner(
        args: [],
        capture: capture,
      );

      expect(exitCode, equals(0));
      expect(capture.output, contains('Usage:'));
    });

    test('pvm -h shows help (short flag)', () async {
      final exitCode = await runPvmCommandRunner(
        args: ['-h'],
        capture: capture,
      );

      expect(exitCode, equals(0));
      expect(capture.output, contains('Usage:'));
    });

    test('pvm -v shows version (short flag)', () async {
      final exitCode = await runPvmCommandRunner(
        args: ['-v'],
        capture: capture,
      );

      expect(exitCode, equals(0));
      expect(capture.output, contains('PVM version: $packageVersion'));
    });
  });
}
