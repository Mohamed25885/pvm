import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/commands/uninstall_command.dart';
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/symlink_inspector.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

void main() {
  group('UninstallCommand', () {
    late MockOSManager osManager;
    late MockConsole console;
    late SymLinkInspector inspector;

    setUp(() {
      osManager = MockOSManager()
        ..mockHomeDir = r'C:\Users\sam'
        ..mockProgramDir = r'C:\pvm'
        ..mockCurrentDirectory = r'D:\proj'
        ..mockVersions = ['8.2.10', '8.2.15', '8.3.0'];
      console = MockConsole();
      inspector = SymLinkInspector(osManager);

      for (final v in ['8.2.10', '8.2.15', '8.3.0']) {
        final dir = p.join(r'C:\pvm\versions', v);
        osManager.setDirectoryExistsResult(dir, true);
      }
      osManager.setDirectoryExistsResult(r'C:\pvm\versions', true);
    });

    Future<int> run(List<String> args) async {
      final runner = CommandRunner<int>('pvm', 'test');
      runner.addCommand(
        UninstallCommand(
          osManager: osManager,
          symlinkInspector: inspector,
          console: console,
        ),
      );
      return await runner.run(['uninstall', ...args]) ?? 1;
    }

    test('usage error when no version', () async {
      final code = await run([]);
      expect(code, equals(ExitCode.usageError));
    });

    test('versionNotFound when not installed', () async {
      final code = await run(['9.9.9', '--yes']);
      expect(code, equals(ExitCode.versionNotFound));
    });

    test('blocks uninstall of active global without --force', () async {
      final vdir = p.join(r'C:\pvm\versions', '8.3.0');
      final globalLink = p.join(r'C:\Users\sam', PvmConstants.pvmDirName);
      osManager.symlinkTargets[globalLink] = vdir;

      final code = await run(['8.3.0', '--yes']);

      expect(code, equals(ExitCode.generalError));
      expect(osManager.deletedDirectories, isEmpty);
    });

    test('--force uninstalls active global', () async {
      final vdir = p.join(r'C:\pvm\versions', '8.3.0');
      final globalLink = p.join(r'C:\Users\sam', PvmConstants.pvmDirName);
      osManager.symlinkTargets[globalLink] = vdir;

      final code = await run(['8.3.0', '--force']);

      expect(code, equals(ExitCode.success));
      expect(osManager.deletedDirectories, contains(vdir));
      expect(osManager.deletedSymLinks, contains(globalLink));
    });

    test('short 8.2 resolves when only one 8.2.x installed', () async {
      osManager.mockVersions = ['8.2.15', '8.3.0'];
      for (final v in ['8.2.15', '8.3.0']) {
        osManager.setDirectoryExistsResult(p.join(r'C:\pvm\versions', v), true);
      }

      final code = await run(['8.2', '--yes']);

      expect(code, equals(ExitCode.success));
      final expected = p.join(r'C:\pvm\versions', '8.2.15');
      expect(osManager.deletedDirectories, contains(expected));
    });

    test('short 8.2 fails when multiple 8.2.x installed', () async {
      final code = await run(['8.2', '--yes']);

      expect(code, equals(ExitCode.versionNotFound));
      expect(console.errors.last, contains('ambiguous'));
      expect(osManager.deletedDirectories, isEmpty);
    });

    test('--yes skips confirmation', () async {
      console.simulateInput('n');

      final code = await run(['8.3.0', '--yes']);

      expect(code, equals(ExitCode.success));
    });

    test('user cancel returns userCancelled', () async {
      console.simulateInput('n');

      final code = await run(['8.3.0']);

      expect(code, equals(ExitCode.userCancelled));
    });

    test('--keep-symlinks does not remove global link', () async {
      final vdir = p.join(r'C:\pvm\versions', '8.3.0');
      final globalLink = p.join(r'C:\Users\sam', PvmConstants.pvmDirName);
      osManager.symlinkTargets[globalLink] = vdir;

      final code = await run(['8.3.0', '--force', '--keep-symlinks']);

      expect(code, equals(ExitCode.success));
      expect(osManager.deletedSymLinks, isEmpty);
    });
  });
}
