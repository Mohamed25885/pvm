import 'dart:io';

import 'package:test/test.dart';

import 'package:pvm/src/managers/windows_environment_configurator.dart';

void main() {
  group('WindowsEnvironmentConfigurator', () {
    late List<({String executable, List<String> args})> calls;
    late Map<String, ProcessResult> responses;

    ProcessResult result({
      int exitCode = 0,
      String stdout = '',
      String stderr = '',
    }) => ProcessResult(0, exitCode, stdout, stderr);

    Future<ProcessResult> mockRun(String executable, List<String> args) async {
      calls.add((executable: executable, args: args));
      final key = '$executable ${args.join(' ')}';
      if (executable == 'reg' && args.contains('Path')) {
        return responses['path_reg'] ??
            responses[key] ??
            result(stdout: 'Path    REG_EXPAND_SZ    C:\\PVM\n');
      }
      return responses[key] ?? result();
    }

    setUp(() {
      calls = [];
      responses = {};
    });

    WindowsEnvironmentConfigurator configurator() =>
        WindowsEnvironmentConfigurator(runProcess: mockRun);

    test('canPersistEnvironment is true', () {
      expect(configurator().canPersistEnvironment, isTrue);
    });

    test('getUserEnvironmentVariable queries HKCU via reg', () async {
      responses['reg query HKCU\\Environment /v PVM_HOME'] = result(
        stdout: 'PVM_HOME    REG_EXPAND_SZ    C:\\pvm\n',
      );

      final value = await configurator().getUserEnvironmentVariable('PVM_HOME');

      expect(value, 'C:\\pvm');
      expect(calls.single.executable, 'reg');
      expect(calls.single.args, contains('PVM_HOME'));
    });

    test('getUserEnvironmentVariable returns null on reg failure', () async {
      responses['reg query HKCU\\Environment /v Missing'] = result(exitCode: 1);

      final value = await configurator().getUserEnvironmentVariable('Missing');

      expect(value, isNull);
    });

    test('setUserEnvironmentVariable uses setx', () async {
      responses['setx PVM_HOME C:\\pvm'] = result();

      await configurator().setUserEnvironmentVariable('PVM_HOME', r'C:\pvm');

      expect(calls.single.executable, 'setx');
      expect(calls.single.args, ['PVM_HOME', r'C:\pvm']);
    });

    test('setUserEnvironmentVariable throws on setx failure', () async {
      responses['setx PVM_HOME bad'] = result(
        exitCode: 1,
        stderr: 'access denied',
      );

      await expectLater(
        configurator().setUserEnvironmentVariable('PVM_HOME', 'bad'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to set PVM_HOME'),
          ),
        ),
      );
    });

    test('getPath reads Path variable', () async {
      responses['reg query HKCU\\Environment /v Path'] = result(
        stdout: 'Path    REG_EXPAND_SZ    C:\\bin;C:\\pvm\n',
      );

      final path = await configurator().getPath();

      expect(path, 'C:\\bin;C:\\pvm');
    });

    test('ensurePathEntries appends missing normalized entries', () async {
      responses['reg query HKCU\\Environment /v Path'] = result(
        stdout: 'Path    REG_EXPAND_SZ    C:\\existing\n',
      );
      responses['setx Path C:\\existing;C:\\pvm'] = result();

      await configurator().ensurePathEntries([r'C:\pvm', r'C:\Users\me\.pvm']);

      expect(
        calls.where((c) => c.executable == 'setx').single.args.first,
        'Path',
      );
      expect(
        calls.where((c) => c.executable == 'setx').single.args.last,
        contains(r'C:\pvm'),
      );
    });

    test('ensurePathEntries skips segments already on PATH', () async {
      responses['path_reg'] = result(
        stdout: 'Path    REG_SZ    C:\\PVM;C:\\Windows\n',
      );

      await configurator().ensurePathEntries([r'C:\PVM']);

      expect(calls.where((x) => x.executable == 'setx'), isEmpty);
    });
  });
}
