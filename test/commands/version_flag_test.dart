import 'dart:io';

import 'package:test/test.dart';

import '../helpers.dart';
import '../mocks/mock_os_manager.dart';

void main() {
  group('Version flag tests', () {
    late MockOSManager osManager;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pvm-version-test-');
      osManager = MockOSManager();
      osManager.mockCurrentDirectory = tempDir.path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('--version flag prints version and exits with 0', () async {
      final runner = TestPvmCommandRunner(osManager: osManager);
      final output = <String>[];

      await runner.runAndCapture(['--version'], capturedOutput: output);
      expect(output.join('\n'), contains('PVM version:'));
    });

    test('-v short flag prints version and exits with 0', () async {
      final runner = TestPvmCommandRunner(osManager: osManager);
      final output = <String>[];

      await runner.runAndCapture(['-v'], capturedOutput: output);
      expect(output.join('\n'), contains('PVM version:'));
    });

    test('--version takes precedence over command arguments', () async {
      final runner = TestPvmCommandRunner(osManager: osManager);
      final output = <String>[];

      await runner.runAndCapture(['--version', 'global', '8.2'],
          capturedOutput: output);

      final outputText = output.join('\n');
      expect(outputText, contains('PVM version:'));
      expect(outputText, isNot(contains('Global link created')));
    });

    test('--help still works as before', () async {
      final runner = TestPvmCommandRunner(osManager: osManager);
      final output = <String>[];

      await runner.runAndCapture(['--help'], capturedOutput: output);

      final helpText = output.join('\n');
      expect(helpText, contains('PHP Version Manager'));
      expect(helpText, contains('global'));
      expect(helpText, contains('use'));
      expect(helpText, contains('list'));
      expect(helpText, contains('php'));
      expect(helpText, contains('composer'));
      expect(helpText, isNot(contains('PVM version:')));
    });
  });
}
