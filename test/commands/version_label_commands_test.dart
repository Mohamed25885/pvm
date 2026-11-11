import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/commands/current_command.dart';
import 'package:pvm/src/commands/doctor_command.dart';
import 'package:pvm/src/commands/global_command.dart';
import 'package:pvm/src/commands/list_command.dart';
import 'package:pvm/src/commands/use_command.dart';
import 'package:pvm/src/core/active_version_resolver.dart';
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/platform_constants.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/symlink_inspector.dart';
import 'package:pvm/src/domain/install_record.dart';

import '../helpers.dart';
import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';
import '../support/temp_dir.dart';

/// Slot `8.5` installed with record `8.5.22`, activated globally.
void main() {
  late Directory root;
  late MockOSManager os;
  late MockConsole console;
  late String slotDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pvm_label_cmds_');
    addTearDown(() => deleteTemp(root));
    slotDir = p.join(root.path, 'versions', '8.5');
    await Directory(slotDir).create(recursive: true);
    await InstallRecord(
      version: '8.5.22',
      sourceUrl: '',
      archiveSha256: '',
      verified: true,
      installedAt: DateTime.utc(2026),
      files: const {},
    ).writeTo(slotDir);
    final home = p.join(root.path, 'home');
    final project = p.join(root.path, 'project');
    await Directory(project).create(recursive: true);
    os = MockOSManager()
      ..mockProgramDir = root.path
      ..mockHomeDir = home
      ..mockCurrentDirectory = project
      ..mockLocalPath = p.join(project, PvmConstants.pvmDirName)
      ..mockVersions = ['8.5']
      ..symlinkSourceExistsOverride = true
      ..symlinkTargets[p.join(home, PvmConstants.pvmDirName)] = slotDir;
    os.setDirectoryExistsResult(p.join(root.path, 'versions'), true);
    os.setDirectoryExistsResult(slotDir, true);
    os.setFileExistsResult(p.join(slotDir, 'php.exe'), true);
    console = MockConsole();
  });

  Future<void> run(Command<int> command, List<String> args) async {
    final runner = CommandRunner<int>('pvm', 't')..addCommand(command);
    await runner.run([command.name, ...args]);
  }

  test('list', () async {
    await run(ListCommand(os, console), []);
    expect(console.printed.join('\n'), contains('8.5 (8.5.22)'));
  });

  test('current', () async {
    final resolver = ActiveVersionResolver(SymLinkInspector(os));
    await run(CurrentCommand(os, resolver, console), []);
    expect(console.printed.join('\n'), contains('Global   : 8.5 (8.5.22)'));
    expect(console.printed.join('\n'), contains('Effective: 8.5 (8.5.22)'));
  });

  test('global', () async {
    await run(GlobalCommand(os, MockVersionActivator(os), console), ['8.5']);
    expect(console.printed.join('\n'), contains('8.5 (8.5.22)'));
  });

  test('use', () async {
    final cmd = UseCommand(
      os,
      FakePhpVersionManager(console),
      FakeGitIgnoreService(os, console),
      MockVersionActivator(os),
      console,
    );
    await run(cmd, ['8.5']);
    expect(console.printed.join('\n'), contains('8.5 (8.5.22)'));
  });

  test('doctor', () async {
    final resolver = ActiveVersionResolver(SymLinkInspector(os));
    await run(
      DoctorCommand(
        osManager: os,
        platformConstants: PlatformConstants(WindowsPlatformInfo()),
        console: console,
        resolver: resolver,
      ),
      ['--no-symlink-test'],
    );
    final out = console.printed.join('\n');
    expect(out, contains('- 8.5 (8.5.22)'));
    expect(out, contains('effective: 8.5 (8.5.22) (global)'));
  });
}
