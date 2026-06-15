import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/commands/global_command.dart';
import 'package:pvm/src/core/exit_codes.dart';

import '../helpers.dart';
import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

void main() {
  group('GlobalCommand', () {
    late MockOSManager osManager;
    late MockConsole console;
    late MockVersionActivator activator;

    setUp(() {
      osManager = MockOSManager()
        ..mockHomeDir = r'C:\Users\sam'
        ..mockProgramDir = r'C:\pvm'
        ..mockVersions = ['8.4.0', '8.4.1', '8.3.0']
        ..symlinkSourceExistsOverride = true;
      console = MockConsole();
      activator = MockVersionActivator(osManager);
      for (final v in ['8.4.0', '8.4.1', '8.3.0']) {
        osManager.setDirectoryExistsResult(p.join(r'C:\pvm\versions', v), true);
      }
      osManager.setDirectoryExistsResult(r'C:\pvm\versions', true);
    });

    Future<int> run(List<String> args) async {
      final runner = CommandRunner<int>('test', 'test');
      runner.addCommand(GlobalCommand(osManager, activator, console));
      return await runner.run(['global', ...args]) ?? 1;
    }

    test('major.minor resolves when exactly one matching version', () async {
      osManager.mockVersions = ['8.4.1', '8.3.0'];
      osManager.setDirectoryExistsResult(
        p.join(r'C:\pvm\versions', '8.4.1'),
        true,
      );

      final code = await run(['8.4']);

      expect(code, ExitCode.success);
      expect(activator.activateGlobalVersion, '8.4.1');
    });

    test('major.minor fails when multiple patches installed', () async {
      final code = await run(['8.4']);

      expect(code, ExitCode.versionNotFound);
      expect(activator.activateGlobalCalled, isFalse);
      expect(console.errors.last, contains('ambiguous'));
    });

    test('exact patch version activates', () async {
      final code = await run(['8.4.1']);

      expect(code, ExitCode.success);
      expect(activator.activateGlobalVersion, '8.4.1');
    });
  });
}
