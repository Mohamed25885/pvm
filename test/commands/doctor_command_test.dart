import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/commands/doctor_command.dart';
import 'package:pvm/src/core/active_version_resolver.dart';
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/platform_constants.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/symlink_inspector.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

void main() {
  group('DoctorCommand', () {
    late MockOSManager osManager;
    late MockConsole console;
    late SymLinkInspector inspector;
    late ActiveVersionResolver resolver;
    late Directory tempHome;

    setUp(() async {
      tempHome = await Directory.systemTemp.createTemp('pvm_doctor_home_');
      osManager = MockOSManager()
        ..mockHomeDir = tempHome.path
        ..mockProgramDir = r'C:\pvm'
        ..mockVersions = ['8.2.10', '8.3.0'];
      console = MockConsole();
      inspector = SymLinkInspector(osManager);
      resolver = ActiveVersionResolver(inspector);

      final v82 = r'C:\pvm\versions\8.2.10';
      final v83 = r'C:\pvm\versions\8.3.0';
      osManager.setDirectoryExistsResult(r'C:\pvm\versions', true);
      osManager.setDirectoryExistsResult(v82, true);
      osManager.setDirectoryExistsResult(v83, true);
      osManager.setFileExistsResult(r'C:\pvm\versions\8.2.10\php.exe', true);
      osManager.setFileExistsResult(r'C:\pvm\versions\8.3.0\php.exe', true);

      final globalLink = p.join(tempHome.path, PvmConstants.pvmDirName);
      osManager.symlinkTargets[globalLink] = v82;
      osManager.setDirectoryExistsResult(v82, true);

      osManager.mockEnvironment = {
        'PATH': '$globalLink;C:\\Windows',
      };
    });

    tearDown(() async {
      if (await tempHome.exists()) {
        await tempHome.delete(recursive: true);
      }
    });

    Future<int> runDoctor(List<String> args) async {
      final runner = CommandRunner<int>('pvm', 'test');
      runner.addCommand(DoctorCommand(
        osManager: osManager,
        platformConstants: PlatformConstants(WindowsPlatformInfo()),
        console: console,
        resolver: resolver,
      ));
      return await runner.run(['doctor', ...args]) ?? 1;
    }

    test('exits success when no failures (symlink probe skipped)', () async {
      final code = await runDoctor(['--no-symlink-test']);

      expect(code, equals(ExitCode.success));
      final out = console.printed.join('\n');
      expect(out, contains('PVM Installation'));
      expect(out, contains('Versions directory'));
      expect(out, contains('Summary:'));
    });

    test('--json emits valid JSON', () async {
      await runDoctor(['--json', '--no-symlink-test']);

      final raw = console.printed.join('\n');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final checks = decoded['checks'] as List<dynamic>;
      expect(checks, isNotEmpty);
      expect((checks.first as Map)['id'], isNotNull);
    });

    test('symlink probe skipped line when --no-symlink-test', () async {
      await runDoctor(['--no-symlink-test']);

      expect(console.printed.join('\n'), contains('Skipped'));
    });

    test('warns when versions directory missing', () async {
      osManager.setDirectoryExistsResult(r'C:\pvm\versions', false);
      osManager.mockVersions = [];

      await runDoctor(['--no-symlink-test']);

      final out = console.printed.join('\n');
      expect(out, contains('[warn]'));
      expect(out, contains('Versions directory'));
    });
  });
}
