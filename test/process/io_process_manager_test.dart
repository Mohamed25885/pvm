import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';

import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/process/io_process_manager.dart';
import '../services/fake_os_manager.dart';

void main() {
  group('IOProcessManager interactive execution', () {
    late IOProcessManager processManager;
    late Directory tempDirectory;
    late FakeOSManager osManager;

    setUp(() async {
      osManager = FakeOSManager()..environment = Platform.environment;
      processManager = IOProcessManager(osManager: osManager);
      tempDirectory = await Directory.systemTemp.createTemp('pvm-io-process-');
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('interactive execution preserves exit code', () async {
      final scriptFile =
          File('${tempDirectory.path}${Platform.pathSeparator}exit_code.dart');
      await scriptFile.writeAsString('''
import 'dart:io';

void main() {
  exit(73);
}
''');

      final exitCode = await processManager.runInteractive(
        ProcessSpec(
          executable: Platform.resolvedExecutable,
          arguments: [scriptFile.path],
        ),
      );

      expect(exitCode, equals(73));
    });

    test('interactive execution preserves working directory and environment',
        () async {
      final scriptFile =
          File('${tempDirectory.path}${Platform.pathSeparator}cwd_env.dart');
      await scriptFile.writeAsString('''
import 'dart:io';

void main() {
  final hasMarker = File('cwd_marker.txt').existsSync();
  final envMatches = Platform.environment['PVM_TEST_INTERACTIVE_ENV'] ==
      'expected-value';

  exit(hasMarker && envMatches ? 0 : 41);
}
''');

      final workingDirectory =
          await Directory.systemTemp.createTemp('pvm io cwd ');
      addTearDown(() async {
        if (await workingDirectory.exists()) {
          await workingDirectory.delete(recursive: true);
        }
      });

      final markerFile = File(
        '${workingDirectory.path}${Platform.pathSeparator}cwd_marker.txt',
      );
      await markerFile.writeAsString('marker');

      final exitCode = await processManager.runInteractive(
        ProcessSpec(
          executable: Platform.resolvedExecutable,
          arguments: [scriptFile.path],
          workingDirectory: workingDirectory.path,
          environment: {'PVM_TEST_INTERACTIVE_ENV': 'expected-value'},
        ),
      );

      expect(exitCode, equals(0));
    });

    test('interactive execution reports process start failures', () async {
      final missingExecutable =
          '${tempDirectory.path}${Platform.pathSeparator}missing interactive executable';

      await expectLater(
        () => processManager.runInteractive(
          ProcessSpec(executable: missingExecutable),
        ),
        throwsA(isA<ProcessException>()),
      );
    });
  });

  group('IOProcessManager captured execution', () {
    late IOProcessManager processManager;
    late Directory tempDirectory;
    late FakeOSManager osManager;

    setUp(() async {
      osManager = FakeOSManager()..environment = Platform.environment;
      processManager = IOProcessManager(osManager: osManager);
      tempDirectory = await Directory.systemTemp.createTemp('pvm-io-process-');
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('captured execution returns stdout stderr and exit code separately',
        () async {
      final scriptFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}captured_split.dart',
      );
      await scriptFile.writeAsString('''
import 'dart:io';

void main() {
  stdout.writeln('captured-stdout');
  stderr.writeln('captured-stderr');
  exit(23);
}
''');

      final result = await processManager.runCaptured(
        ProcessSpec(
          executable: Platform.resolvedExecutable,
          arguments: [scriptFile.path],
        ),
      );

      expect(result.stdout, contains('captured-stdout'));
      expect(result.stdout, isNot(contains('captured-stderr')));
      expect(result.stderr, contains('captured-stderr'));
      expect(result.stderr, isNot(contains('captured-stdout')));
      expect(result.exitCode, equals(23));
    });

    test('captured execution does not require terminal inheritance', () async {
      final scriptFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}captured_no_terminal.dart',
      );
      await scriptFile.writeAsString('''
import 'dart:io';

void main() {
  final hasMarker = File('cwd_marker.txt').existsSync();
  final envMatches = Platform.environment['PVM_TEST_CAPTURED_ENV'] ==
      'expected-value';

  if (!hasMarker || !envMatches) {
    stderr.writeln('missing context');
    exit(41);
  }

  stdout.writeln('captured-ok');
}
''');

      final workingDirectory =
          await Directory.systemTemp.createTemp('pvm-io-captured-cwd-');
      addTearDown(() async {
        if (await workingDirectory.exists()) {
          await workingDirectory.delete(recursive: true);
        }
      });

      final markerFile = File(
        '${workingDirectory.path}${Platform.pathSeparator}cwd_marker.txt',
      );
      await markerFile.writeAsString('marker');

      final result = await processManager.runCaptured(
        ProcessSpec(
          executable: Platform.resolvedExecutable,
          arguments: [scriptFile.path],
          workingDirectory: workingDirectory.path,
          environment: {'PVM_TEST_CAPTURED_ENV': 'expected-value'},
        ),
      );

      expect(result.stdout, contains('captured-ok'));
      expect(result.stderr.trim(), isEmpty);
      expect(result.exitCode, equals(0));
    });

    test('captured execution preserves non-zero exit code', () async {
      final scriptFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}captured_exit_code.dart',
      );
      await scriptFile.writeAsString('''
import 'dart:io';

void main() {
  exit(73);
}
''');

      final result = await processManager.runCaptured(
        ProcessSpec(
          executable: Platform.resolvedExecutable,
          arguments: [scriptFile.path],
        ),
      );

      expect(result.exitCode, equals(73));
    });

    test('captured execution handles script paths with spaces', () async {
      final spacedDirectory = Directory(
        '${tempDirectory.path}${Platform.pathSeparator}spaced folder',
      );
      await spacedDirectory.create(recursive: true);

      final scriptFile = File(
        '${spacedDirectory.path}${Platform.pathSeparator}script with spaces.dart',
      );
      await scriptFile.writeAsString('''
import 'dart:io';

void main() {
  stdout.writeln('spaced-path-ok');
}
''');

      final result = await processManager.runCaptured(
        ProcessSpec(
          executable: Platform.resolvedExecutable,
          arguments: [scriptFile.path],
        ),
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('spaced-path-ok'));
      expect(result.stderr.trim(), isEmpty);
    });

    test('captured execution keeps heavy stdout and stderr separated',
        () async {
      final scriptFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}captured_heavy_split.dart',
      );
      await scriptFile.writeAsString('''
import 'dart:io';

void main() {
  for (var i = 0; i < 200; i++) {
    stdout.writeln('out:4i');
    stderr.writeln('err:4i');
  }
  exit(19);
}
''');

      final result = await processManager.runCaptured(
        ProcessSpec(
          executable: Platform.resolvedExecutable,
          arguments: [scriptFile.path],
        ),
      );

      final stdoutLines = const LineSplitter()
          .convert(result.stdout)
          .where((line) => line.isNotEmpty)
          .toList();
      final stderrLines = const LineSplitter()
          .convert(result.stderr)
          .where((line) => line.isNotEmpty)
          .toList();

      expect(stdoutLines, hasLength(200));
      expect(stderrLines, hasLength(200));
      expect(stdoutLines.every((line) => line.startsWith('out:')), isTrue);
      expect(stderrLines.every((line) => line.startsWith('err:')), isTrue);
      expect(result.exitCode, equals(19));
    });

    test('captured execution reports process start failure clearly', () async {
      final missingExecutable =
          '${tempDirectory.path}${Platform.pathSeparator}missing_executable';

      await expectLater(
        () => processManager.runCaptured(
          ProcessSpec(executable: missingExecutable),
        ),
        throwsA(
          isA<Exception>()
              .having(
                (error) => error.toString(),
                'error text',
                contains('Failed to start process'),
              )
              .having(
                (error) => error.toString(),
                'missing executable path',
                contains(missingExecutable),
              ),
        ),
      );
    });

    test('resolveSystemCommand uses PATH to resolve executable', () async {
      final command = Platform.isWindows ? 'dart' : 'dart';
      final resolved = await processManager.resolveSystemCommand(command);

      expect(resolved, isNot(command));
      expect(resolved, contains(Platform.pathSeparator));
      expect(await File(resolved).exists(), isTrue);
    });

    test('resolveSystemCommand returns original command when not found',
        () async {
      const missingCommand = 'pvm_test_command_that_does_not_exist';
      final resolved =
          await processManager.resolveSystemCommand(missingCommand);

      expect(resolved, equals(missingCommand));
    });
  });
}
