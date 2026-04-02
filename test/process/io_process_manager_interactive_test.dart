import 'dart:io';
import 'package:test/test.dart';

import '../../lib/src/core/process_manager.dart';
import '../../lib/src/process/io_process_manager.dart';

void main() {
  group('IOProcessManager.runInteractive', () {
    late IOProcessManager processManager;
    late Directory tempDirectory;

    setUp(() async {
      processManager = IOProcessManager();
      tempDirectory = await Directory.systemTemp.createTemp('pvm-interactive-');
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('returns correct exit code from child process', () async {
      final scriptFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}exit_42.dart',
      );
      await scriptFile.writeAsString('''
import 'dart:io';

void main() {
  exit(42);
}
''');

      final exitCode = await processManager.runInteractive(
        ProcessSpec(
          executable: Platform.resolvedExecutable,
          arguments: [scriptFile.path],
        ),
      );

      expect(exitCode, equals(42));
    });

    test('child process writes to stdout/stderr without exceptions', () async {
      final scriptFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}output_test.dart',
      );
      await scriptFile.writeAsString('''
import 'dart:io';

void main() {
  stdout.writeln('Hello from stdout');
  stderr.writeln('Hello from stderr');
  exit(0);
}
''');

      final exitCode = await processManager.runInteractive(
        ProcessSpec(
          executable: Platform.resolvedExecutable,
          arguments: [scriptFile.path],
        ),
      );

      expect(exitCode, equals(0));
    });

    test('preserves working directory', () async {
      final scriptFile = File(
        '${tempDirectory.path}${Platform.pathSeparator}cwd_test.dart',
      );

      final workingDir = await Directory.systemTemp.createTemp('pvm-cwd-');
      addTearDown(() async {
        if (await workingDir.exists()) {
          await workingDir.delete(recursive: true);
        }
      });

      // Escape backslashes for inclusion in a Dart string literal
      final escapedPath = workingDir.path.replaceAll(r'\', r'\\');

      await scriptFile.writeAsString('''
import 'dart:io';

void main() {
  final currentDir = Directory.current.path;
  final expectedDir = '$escapedPath';
  if (currentDir != expectedDir) {
    stderr.writeln('Wrong directory: \$currentDir != \$expectedDir');
    exit(1);
  }
  exit(0);
}
''');

      final exitCode = await processManager.runInteractive(
        ProcessSpec(
          executable: Platform.resolvedExecutable,
          arguments: [scriptFile.path],
          workingDirectory: workingDir.path,
        ),
      );

      expect(exitCode, equals(0));
    });
  });
}
