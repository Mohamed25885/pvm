import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import '../helpers.dart';
import '../mocks/mock_os_manager.dart';
import 'package:pvm/src/core/process_manager.dart';

void main() {
  group('Global flag intercept tests', () {
    late MockOSManager osManager;

    setUp(() {
      osManager = MockOSManager();
    });

    test('pvm --version shows PVM version and exits 0', () async {
      final runner = TestPvmCommandRunner(osManager: osManager);
      final output = <String>[];

      await runZoned(
        () async {
          final result = await runner.run(['--version']);
          expect(result, 0);
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            output.add(line);
          },
        ),
      );

      expect(output.join('\n'), contains('PVM version:'));
    });

    test('pvm --help shows top-level help and exits 0', () async {
      final runner = TestPvmCommandRunner(osManager: osManager);
      final output = <String>[];

      await runZoned(
        () async {
          final result = await runner.run(['--help']);
          expect(result, 0);
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            output.add(line);
          },
        ),
      );

      final helpText = output.join('\n');
      expect(helpText, contains('PHP Version Manager'));
      expect(helpText, contains('global'));
      expect(helpText, contains('use'));
      expect(helpText, contains('list'));
      expect(helpText, contains('php'));
      expect(helpText, contains('composer'));
    });

    test(
        'pvm php --version delegates to PhpCommand (does not show PVM version)',
        () async {
      // Setup: create a project directory with .php-version and .pvm/php.exe
      final tempDir = await Directory.systemTemp.createTemp('pvm-php-test-');
      await File('${tempDir.path}\\.php-version').writeAsString('8.2\n');
      await Directory('${tempDir.path}\\.pvm').create();
      await File('${tempDir.path}\\.pvm\\php.exe').create();

      osManager.mockCurrentDirectory = tempDir.path;

      // Use a custom process manager to simulate PHP --version output
      final processManager = RecordingProcessManager(
        exitCodeToReturn: 0,
        stdoutToReturn: 'PHP 8.2.0 (cli) ...',
      );

      final runner = TestPvmCommandRunner(
        osManager: osManager,
        processManager: processManager,
      );
      final output = <String>[];

      final exitCode = await runner
          .runAndCapture(['php', '--version'], capturedOutput: output);

      // Verify delegation: exit code from PhpCommand (0)
      expect(exitCode, equals(0));

      // Verify that the process manager was called (PhpCommand executed)
      expect(processManager.runInteractiveCallCount, equals(1));
      expect(processManager.lastInteractiveSpec?.executable,
          endsWith(r'\.pvm\php.exe'));
      expect(processManager.lastInteractiveSpec?.arguments,
          orderedEquals(['--version']));

      // Verify PVM version was NOT printed
      expect(output.join('\n'), isNot(contains('PVM version:')));
    });

    test('pvm php --help delegates to PhpCommand help', () async {
      final tempDir = await Directory.systemTemp.createTemp('pvm-php-test-');
      await File('${tempDir.path}\\.php-version').writeAsString('8.2\n');
      await Directory('${tempDir.path}\\.pvm').create();
      await File('${tempDir.path}\\.pvm\\php.exe').create();

      osManager.mockCurrentDirectory = tempDir.path;

      final processManager = RecordingProcessManager(
        exitCodeToReturn: 0,
        stdoutToReturn: 'PHP Help output...',
      );

      final runner = TestPvmCommandRunner(
        osManager: osManager,
        processManager: processManager,
      );
      final output = <String>[];

      final exitCode =
          await runner.runAndCapture(['php', '--help'], capturedOutput: output);

      expect(exitCode, equals(0));
      expect(processManager.runInteractiveCallCount, equals(1));
      expect(processManager.lastInteractiveSpec?.executable,
          endsWith(r'\.pvm\php.exe'));
      expect(processManager.lastInteractiveSpec?.arguments,
          orderedEquals(['--help']));

      expect(output.join('\n'), isNot(contains('Usage:')));
    });

    test('pvm --help with no args shows help', () async {
      final runner = TestPvmCommandRunner(osManager: osManager);
      final output = <String>[];

      await runZoned(
        () async {
          final result = await runner.run(['--help']);
          expect(result, 0);
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            output.add(line);
          },
        ),
      );

      expect(output.join('\n'), contains('Usage:'));
    });

    test('pvm -h shows help (short flag)', () async {
      final runner = TestPvmCommandRunner(osManager: osManager);
      final output = <String>[];

      await runZoned(
        () async {
          final result = await runner.run(['-h']);
          expect(result, 0);
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            output.add(line);
          },
        ),
      );

      expect(output.join('\n'), contains('Usage:'));
    });

    test('pvm -v shows version (short flag)', () async {
      final runner = TestPvmCommandRunner(osManager: osManager);
      final output = <String>[];

      await runZoned(
        () async {
          final result = await runner.run(['-v']);
          expect(result, 0);
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            output.add(line);
          },
        ),
      );

      expect(output.join('\n'), contains('PVM version:'));
    });
  });
}

/// Custom ProcessManager for testing that records calls.
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

  @override
  Future<String> resolveSystemCommand(String command) async => command;
}
