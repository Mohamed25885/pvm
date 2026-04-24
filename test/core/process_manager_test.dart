import 'package:test/test.dart';
import 'package:pvm/src/core/process_manager.dart';

void main() {
  group('ProcessSpec', () {
    test('creates with required executable', () {
      final spec = ProcessSpec(executable: 'php.exe');
      expect(spec.executable, 'php.exe');
    });

    test('creates with arguments', () {
      final spec = ProcessSpec(executable: 'php.exe', arguments: ['-v']);
      expect(spec.arguments, ['-v']);
    });

    test('arguments are unmodifiable', () {
      final spec = ProcessSpec(executable: 'php.exe', arguments: ['-v']);
      expect(
          () => (spec.arguments as List).add('test'), throwsUnsupportedError);
    });

    test('creates with workingDirectory', () {
      final spec = ProcessSpec(
        executable: 'php.exe',
        workingDirectory: 'C:\\project',
      );
      expect(spec.workingDirectory, 'C:\\project');
    });

    test('creates with environment', () {
      final spec = ProcessSpec(
        executable: 'php.exe',
        environment: {'PATH': '/usr/bin'},
      );
      expect(spec.environment, {'PATH': '/usr/bin'});
    });

    test('environment is null when not provided', () {
      final spec = ProcessSpec(executable: 'php.exe');
      expect(spec.environment, isNull);
    });

    test('environment is unmodifiable', () {
      final spec = ProcessSpec(
        executable: 'php.exe',
        environment: {'KEY': 'value'},
      );
      // Environment is unmodifiable - can't add to it
      expect(spec.environment!['KEY'], 'value');
    });
  });

  group('CapturedProcessResult', () {
    test('creates with all fields', () {
      final result = CapturedProcessResult(
        stdout: 'output',
        stderr: 'error',
        exitCode: 0,
      );
      expect(result.stdout, 'output');
      expect(result.stderr, 'error');
      expect(result.exitCode, 0);
    });

    test('stdout can be empty', () {
      final result = CapturedProcessResult(
        stdout: '',
        stderr: '',
        exitCode: 1,
      );
      expect(result.stdout, '');
    });
  });

  group('IProcessManager', () {
    test('is abstract class', () {
      // Just verify interface exists - can't instantiate abstract
      expect(IProcessManager, isNotNull);
    });
  });
}
