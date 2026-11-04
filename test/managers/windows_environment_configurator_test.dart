import 'dart:io';

import 'package:test/test.dart';

import 'package:pvm/src/managers/windows_environment_configurator.dart';

void main() {
  group('WindowsEnvironmentConfigurator', () {
    late List<({String executable, List<String> args})> calls;
    late Map<String, ProcessResult> responses;
    late List<({String name, String value})> backups;

    ProcessResult result({
      int exitCode = 0,
      String stdout = '',
      String stderr = '',
    }) => ProcessResult(0, exitCode, stdout, stderr);

    Future<ProcessResult> mockRun(String executable, List<String> args) async {
      calls.add((executable: executable, args: args));
      final key = '$executable ${args.join(' ')}';
      if (executable == 'reg' &&
          args.first == 'query' &&
          args.contains('Path')) {
        return responses['path_reg'] ??
            responses[key] ??
            result(stdout: '    Path    REG_EXPAND_SZ    C:\\PVM\n');
      }
      return responses[key] ?? result();
    }

    setUp(() {
      calls = [];
      responses = {};
      backups = [];
    });

    WindowsEnvironmentConfigurator configurator() =>
        WindowsEnvironmentConfigurator(
          runProcess: mockRun,
          writeBackup: (name, value) async =>
              backups.add((name: name, value: value)),
        );

    Iterable<List<String>> regAdds() => calls
        .where((c) => c.executable == 'reg' && c.args.first == 'add')
        .map((c) => c.args);

    test('canPersistEnvironment is true', () {
      expect(configurator().canPersistEnvironment, isTrue);
    });

    test('getUserEnvironmentVariable queries HKCU via reg', () async {
      responses['reg query HKCU\\Environment /v PVM_HOME'] = result(
        stdout: '    PVM_HOME    REG_SZ    C:\\pvm\n',
      );

      final value = await configurator().getUserEnvironmentVariable('PVM_HOME');

      expect(value, 'C:\\pvm');
      expect(calls.single.executable, 'reg');
    });

    test('getUserEnvironmentVariable keeps values containing spaces', () async {
      responses['reg query HKCU\\Environment /v PVM_HOME'] = result(
        stdout: '    PVM_HOME    REG_SZ    C:\\Program Files\\pvm\n',
      );

      expect(
        await configurator().getUserEnvironmentVariable('PVM_HOME'),
        r'C:\Program Files\pvm',
      );
    });

    test('getUserEnvironmentVariable returns null when value missing', () async {
      responses['reg query HKCU\\Environment /v Missing'] = result(
        exitCode: 1,
        stderr:
            'ERROR: The system was unable to find the specified registry key or value.',
      );

      expect(
        await configurator().getUserEnvironmentVariable('Missing'),
        isNull,
      );
    });

    test(
      'getUserEnvironmentVariable throws on unexpected reg failure',
      () async {
        responses['reg query HKCU\\Environment /v PVM_HOME'] = result(
          exitCode: 1,
          stderr: 'ERROR: Access is denied.',
        );

        await expectLater(
          configurator().getUserEnvironmentVariable('PVM_HOME'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('setUserEnvironmentVariable uses reg add, never setx', () async {
      await configurator().setUserEnvironmentVariable('PVM_HOME', r'C:\pvm');

      expect(calls.where((c) => c.executable == 'setx'), isEmpty);
      expect(regAdds().single, [
        'add',
        r'HKCU\Environment',
        '/v',
        'PVM_HOME',
        '/t',
        'REG_SZ',
        '/d',
        r'C:\pvm',
        '/f',
      ]);
    });

    test('setUserEnvironmentVariable throws on reg add failure', () async {
      responses['reg add HKCU\\Environment /v PVM_HOME /t REG_SZ /d bad /f'] =
          result(exitCode: 1, stderr: 'access denied');

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
      responses['path_reg'] = result(
        stdout: '    Path    REG_EXPAND_SZ    C:\\bin;C:\\pvm\n',
      );

      expect(await configurator().getPath(), 'C:\\bin;C:\\pvm');
    });

    test('ensurePathEntries appends missing normalized entries', () async {
      responses['path_reg'] = result(
        stdout: '    Path    REG_EXPAND_SZ    C:\\existing\n',
      );

      await configurator().ensurePathEntries([r'C:\pvm', r'C:\Users\me\.pvm']);

      final add = regAdds().single;
      expect(add[3], 'Path');
      expect(add[5], 'REG_EXPAND_SZ');
      expect(add[7], r'C:\existing;C:\pvm;C:\Users\me\.pvm');
    });

    test('ensurePathEntries skips segments already on PATH', () async {
      responses['path_reg'] = result(
        stdout: '    Path    REG_SZ    C:\\PVM;C:\\Windows\n',
      );

      await configurator().ensurePathEntries([r'C:\PVM']);

      expect(regAdds(), isEmpty);
      expect(backups, isEmpty);
    });

    test(
      'ensurePathEntries keeps a PATH longer than 1024 chars intact (S1)',
      () async {
        final long = List.generate(
          120,
          (i) => r'C:\Tools\some-long-folder-name-' + '$i',
        ).join(';');
        expect(long.length, greaterThan(3000));
        responses['path_reg'] = result(
          stdout: '    Path    REG_EXPAND_SZ    $long\n',
        );

        await configurator().ensurePathEntries([r'C:\pvm']);

        expect(regAdds().single[7], '$long;C:\\pvm');
        expect(calls.where((c) => c.executable == 'setx'), isEmpty);
      },
    );

    test('ensurePathEntries preserves REG_EXPAND_SZ %VAR% entries', () async {
      responses['path_reg'] = result(
        stdout: '    Path    REG_EXPAND_SZ    %USERPROFILE%\\bin\n',
      );

      await configurator().ensurePathEntries([r'C:\pvm']);

      final add = regAdds().single;
      expect(add[5], 'REG_EXPAND_SZ');
      expect(add[7], r'%USERPROFILE%\bin;C:\pvm');
    });

    test('ensurePathEntries backs up the previous value first', () async {
      responses['path_reg'] = result(
        stdout: '    Path    REG_EXPAND_SZ    C:\\existing\n',
      );

      await configurator().ensurePathEntries([r'C:\pvm']);

      expect(backups.single, (name: 'Path', value: r'C:\existing'));
    });

    test(
      'ensurePathEntries refuses to write when PATH cannot be read',
      () async {
        responses['path_reg'] = result(
          exitCode: 1,
          stderr: 'ERROR: Access is denied.',
        );

        await expectLater(
          configurator().ensurePathEntries([r'C:\pvm']),
          throwsA(isA<Exception>()),
        );
        expect(regAdds(), isEmpty);
      },
    );

    test('ensurePathEntries broadcasts WM_SETTINGCHANGE', () async {
      responses['path_reg'] = result(
        stdout: '    Path    REG_EXPAND_SZ    C:\\existing\n',
      );

      await configurator().ensurePathEntries([r'C:\pvm']);

      expect(calls.last.executable, 'powershell');
      expect(calls.last.args.last, contains('SendMessageTimeout'));
    });
  });
}
