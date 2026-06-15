import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/commands/setup_command.dart';
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/pvm_paths.dart';
import 'package:pvm/src/domain/project.dart';
import 'package:pvm/src/services/installation/pvm_setup_service.dart';

import '../mocks/fake_environment_configurator.dart';
import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

void main() {
  group('PVM integration', () {
    test('PvmPaths unset matches MockOSManager legacy layout', () {
      const fallback = r'C:\pvm';
      final paths = PvmPaths.fromEnvironment(
        {},
        programDirectoryFallback: fallback,
      );
      final os = MockOSManager()..mockProgramDir = fallback;
      expect(paths.pvmHome, p.normalize(os.programDirectory));
      expect(paths.versionsHome, p.normalize(os.phpVersionsPath));
    });

    test('Project discovers .pvmrc JSON root', () async {
      final dir = await Directory.systemTemp.createTemp('pvm_int_');
      try {
        await File(p.join(dir.path, PvmConstants.pvmrcFileName)).writeAsString(
          const JsonEncoder.withIndent('  ').convert({'version': '8.2'}),
        );
        final nested = Directory(p.join(dir.path, 'src'));
        await nested.create();

        final project = await Project.findFromPath(nested.path);
        expect(project.rootDirectory.path, dir.path);
        expect((await project.getConfiguredVersion()).toString(), '8.2');
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('setup dry-run then paths resolve consistently', () async {
      final os = MockOSManager()
        ..mockProgramDir = r'C:\pvm'
        ..mockHomeDir = r'C:\Users\me'
        ..mockEnvironment = {};
      os.setDirectoryExistsResult(r'C:\pvm', true);
      os.setDirectoryExistsResult(r'C:\pvm\versions', true);

      final configurator = FakeEnvironmentConfigurator();
      final console = MockConsole()..hasTerminal = false;
      final service = PvmSetupService(
        osManager: os,
        configurator: configurator,
        console: console,
      );

      final runner = CommandRunner<int>('pvm', 'test');
      runner.addCommand(
        SetupCommand(
          osManager: os,
          configurator: configurator,
          console: console,
          service: service,
        ),
      );

      final code = await runner.run(['setup', '--dry-run']);
      expect(code, ExitCode.success);

      final paths = PvmPaths.fromEnvironment(
        {},
        programDirectoryFallback: os.programDirectory,
      );
      expect(paths.pvmHome, r'C:\pvm');
      expect(paths.versionsHome, p.join(r'C:\pvm', 'versions'));
    });
  });
}
