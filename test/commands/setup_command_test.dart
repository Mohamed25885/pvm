import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import 'package:pvm/src/commands/setup_command.dart';
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/services/installation/pvm_setup_service.dart';

import '../mocks/fake_environment_configurator.dart';
import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

void main() {
  group('SetupCommand', () {
    late MockOSManager osManager;
    late FakeEnvironmentConfigurator configurator;
    late MockConsole console;

    setUp(() {
      osManager = MockOSManager()
        ..mockProgramDir = r'C:\pvm'
        ..mockHomeDir = r'C:\Users\me'
        ..mockEnvironment = {};
      osManager.setDirectoryExistsResult(r'C:\pvm', true);
      osManager.setDirectoryExistsResult(r'C:\pvm\versions', false);

      configurator = FakeEnvironmentConfigurator();
      console = MockConsole()..hasTerminal = false;
    });

    Future<int> run(List<String> args, {PvmSetupService? service}) async {
      final runner = CommandRunner<int>('pvm', 'test');
      runner.addCommand(
        SetupCommand(
          osManager: osManager,
          configurator: configurator,
          console: console,
          service: service,
        ),
      );
      return await runner.run(['setup', ...args]) ?? 1;
    }

    test('dry-run exits success without persisting env', () async {
      final code = await run(['--dry-run']);

      expect(code, ExitCode.success);
      expect(configurator.variables, isEmpty);
      expect(console.printed.join('\n'), contains('PVM setup plan'));
    });

    test('exits error when preflight fails', () async {
      osManager.setDirectoryExistsResult(r'C:\pvm', false);

      final code = await run(['--yes']);

      expect(code, ExitCode.generalError);
      expect(console.errors, isNotEmpty);
    });

    test('--yes applies setup without confirm prompt', () async {
      final code = await run(['--yes']);

      expect(code, ExitCode.success);
      expect(configurator.variables[PvmConstants.envPvmHome], r'C:\pvm');
      expect(console.printed.join('\n'), contains('Setup complete'));
    });

    test('--versions-home forwards override to service', () async {
      final code = await run(['--yes', '--versions-home', r'D:\custom']);

      expect(code, ExitCode.success);
      expect(
        configurator.variables[PvmConstants.envPvmVersionsHome],
        r'D:\custom',
      );
    });

    test('reports cancellation from service', () async {
      console.hasTerminal = true;
      console.simulateInput('n');
      final service = PvmSetupService(
        osManager: osManager,
        configurator: configurator,
        console: console,
      );

      final code = await run([], service: service);

      expect(code, ExitCode.generalError);
      expect(console.errors.join('\n'), contains('Setup cancelled'));
    });
  });
}
