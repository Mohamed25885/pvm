import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/commands/uninstall_command.dart';
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/symlink_inspector.dart';
import 'package:pvm/src/domain/install_record.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';
import '../support/host_paths.dart';

void main() {
  group('UninstallCommand', () {
    late MockOSManager osManager;
    late MockConsole console;
    late SymLinkInspector inspector;

    setUp(() {
      osManager = MockOSManager()
        ..mockHomeDir = hostPath(r'C:\Users\sam')
        ..mockProgramDir = hostPath(r'C:\pvm')
        ..mockCurrentDirectory = hostPath(r'D:\proj')
        ..mockVersions = ['8.2.10', '8.2.15', '8.3.0'];
      console = MockConsole();
      inspector = SymLinkInspector(osManager);

      for (final v in ['8.2.10', '8.2.15', '8.3.0']) {
        final dir = p.join(hostPath(r'C:\pvm\versions'), v);
        osManager.setDirectoryExistsResult(dir, true);
      }
      osManager.setDirectoryExistsResult(hostPath(r'C:\pvm\versions'), true);
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
      final vdir = p.join(hostPath(r'C:\pvm\versions'), '8.3.0');
      final globalLink = p.join(
        hostPath(r'C:\Users\sam'),
        PvmConstants.pvmDirName,
      );
      osManager.symlinkTargets[globalLink] = vdir;

      final code = await run(['8.3.0', '--yes']);

      expect(code, equals(ExitCode.generalError));
      expect(osManager.deletedDirectories, isEmpty);
    });

    test('--force uninstalls active global', () async {
      final vdir = p.join(hostPath(r'C:\pvm\versions'), '8.3.0');
      final globalLink = p.join(
        hostPath(r'C:\Users\sam'),
        PvmConstants.pvmDirName,
      );
      osManager.symlinkTargets[globalLink] = vdir;

      final code = await run(['8.3.0', '--force']);

      expect(code, equals(ExitCode.success));
      expect(osManager.deletedDirectories, contains(vdir));
      expect(osManager.deletedSymLinks, contains(globalLink));
    });

    test('short 8.2 resolves when only one 8.2.x installed', () async {
      osManager.mockVersions = ['8.2.15', '8.3.0'];
      for (final v in ['8.2.15', '8.3.0']) {
        osManager.setDirectoryExistsResult(
          p.join(hostPath(r'C:\pvm\versions'), v),
          true,
        );
      }

      final code = await run(['8.2', '--yes']);

      expect(code, equals(ExitCode.success));
      final expected = p.join(hostPath(r'C:\pvm\versions'), '8.2.15');
      expect(osManager.deletedDirectories, contains(expected));
    });

    test('short 8.2 fails when multiple 8.2.x installed', () async {
      final code = await run(['8.2', '--yes']);

      expect(code, equals(ExitCode.versionNotFound));
      expect(console.errors.last, contains('ambiguous'));
      expect(osManager.deletedDirectories, isEmpty);
    });

    test(
      'a full patch removes exactly that folder while 8.2 conflicts',
      () async {
        final code = await run(['8.2.10', '--yes']);

        expect(code, equals(ExitCode.success));
        expect(osManager.deletedDirectories, [
          p.join(hostPath(r'C:\pvm\versions'), '8.2.10'),
        ]);
      },
    );

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
      final vdir = p.join(hostPath(r'C:\pvm\versions'), '8.3.0');
      final globalLink = p.join(
        hostPath(r'C:\Users\sam'),
        PvmConstants.pvmDirName,
      );
      osManager.symlinkTargets[globalLink] = vdir;

      final code = await run(['8.3.0', '--force', '--keep-symlinks']);

      expect(code, equals(ExitCode.success));
      expect(osManager.deletedSymLinks, isEmpty);
    });
  });

  group('UninstallCommand with recorded slots', () {
    late Directory temp;
    late MockOSManager osManager;
    late MockConsole console;
    late String versions;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('pvm_uninstall_');
      versions = p.join(temp.path, 'versions');
      osManager = MockOSManager()
        ..mockHomeDir = p.join(temp.path, 'home')
        ..mockProgramDir = temp.path
        ..mockCurrentDirectory = p.join(temp.path, 'proj');
      console = MockConsole();
      osManager.setDirectoryExistsResult(versions, true);
    });

    tearDown(() => temp.delete(recursive: true));

    Future<void> slot(String name, {String? recorded}) async {
      final dir = p.join(versions, name);
      await Directory(dir).create(recursive: true);
      osManager.setDirectoryExistsResult(dir, true);
      osManager.mockVersions = [...osManager.mockVersions, name];
      if (recorded != null) {
        await InstallRecord(
          version: recorded,
          sourceUrl: '',
          archiveSha256: '',
          verified: true,
          installedAt: DateTime.utc(2026),
          files: const {},
        ).writeTo(dir);
      }
    }

    Future<int> run(List<String> args) async {
      final runner = CommandRunner<int>('pvm', 'test')
        ..addCommand(
          UninstallCommand(
            osManager: osManager,
            symlinkInspector: SymLinkInspector(osManager),
            console: console,
          ),
        );
      return await runner.run(['uninstall', ...args]) ?? 1;
    }

    test('refuses a full patch the slot does not hold', () async {
      osManager.mockVersions = [];
      await slot('8.4', recorded: '8.4.27');

      final code = await run(['8.4.1', '--yes']);

      expect(code, ExitCode.versionNotFound);
      expect(console.errors.last, '8.4.1 is not installed; 8.4 holds 8.4.27.');
      expect(osManager.deletedDirectories, isEmpty);
    });

    test('removes the slot by its recorded patch', () async {
      osManager.mockVersions = [];
      await slot('8.4', recorded: '8.4.27');

      final code = await run(['8.4.27', '--yes']);

      expect(code, ExitCode.success);
      expect(osManager.deletedDirectories, [p.join(versions, '8.4')]);
    });

    test(
      'accepts the legacy patch the migration conflict message names',
      () async {
        osManager.mockVersions = [];
        await slot('8.2', recorded: '8.2.30');
        await slot('8.2.28', recorded: '8.2.28');

        expect(await run(['8.2', '--yes']), ExitCode.versionNotFound);
        final code = await run(['8.2.28', '--yes']);

        expect(code, ExitCode.success);
        expect(osManager.deletedDirectories, [p.join(versions, '8.2.28')]);
      },
    );
  });
}
