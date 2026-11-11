import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/commands/link_command.dart';
import 'package:pvm/src/commands/uninstall_command.dart';
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/link_manager.dart';
import 'package:pvm/src/core/php_layout.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/core/symlink_inspector.dart';
import 'package:pvm/src/core/version_label.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/domain/version_registry.dart';
import 'package:pvm/src/managers/io_os_manager.dart';
import 'package:pvm/src/services/folder_probe.dart';

import '../mocks/mock_console.dart';
import '../services/fake_process_manager.dart';

void main() {
  late Directory tmp;
  late String versions;
  late String folder;
  late IoOSManager os;
  late FakeProcessManager pm;
  late MockConsole console;
  late PlatformInfo platform;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pvm_link_');
    versions = p.join(tmp.path, 'home', 'versions');
    Directory(versions).createSync(recursive: true);
    folder = p.join(tmp.path, 'plesk', 'php', '8.4');
    Directory(folder).createSync(recursive: true);
    File(p.join(folder, 'precious.txt')).writeAsStringSync('keep me');
    platform = createPlatformInfo();
    os = IoOSManager(
      platformInfo: platform,
      linkManager: createLinkManager(platform),
      environment: {
        PvmConstants.envPvmHome: p.join(tmp.path, 'home'),
        platform.homeDirectoryKey: p.join(tmp.path, 'user'),
      },
    );
    pm = FakeProcessManager();
    console = MockConsole();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Makes [dir] look like a PHP folder whose php reports [version].
  void fakePhp(String dir, String version) {
    final php = PhpLayout.forPlatform(platform).phpExecutable(dir);
    File(php).createSync(recursive: true);
    pm.capturedResults[php] = CapturedProcessResult(
      stdout: jsonEncode({
        'v': version,
        'zts': false,
        'arch': 'x86_64',
        'ext': p.join(dir, 'ext'),
        'build': 'API20240924,NTS',
      }),
      stderr: '',
      exitCode: 0,
    );
  }

  Future<int> run(List<String> args) async {
    final runner = CommandRunner<int>('pvm', 'test')
      ..addCommand(LinkCommand(os, FolderProbe(pm, platform), console))
      ..addCommand(
        UninstallCommand(
          osManager: os,
          symlinkInspector: SymLinkInspector(os),
          console: console,
        ),
      );
    return await runner.run(args) ?? 1;
  }

  test('links the folder and records it beside the link', () async {
    fakePhp(folder, '8.4.15');

    final code = await run(['link', '8.4', folder]);

    expect(code, ExitCode.success);
    expect(console.printed.last, 'Linked 8.4 (8.4.15) → $folder');
    final slot = p.join(versions, '8.4');
    expect(await os.isSymLink(slot), isTrue);
    final record = await InstallRecord.readFromFile(
      p.join(versions, '8.4.pvm-link.json'),
    );
    expect(record!.kind, SlotKind.linked);
    expect(record.version, '8.4.15');
    expect(record.sourceUrl, folder);
    expect(record.verified, isFalse);
    // PVM wrote nothing inside the user's folder.
    expect(
      Directory(folder).listSync().map((e) => p.basename(e.path)).toSet(),
      containsAll(['precious.txt']),
    );
    expect(File(p.join(folder, InstallRecord.fileName)).existsSync(), isFalse);

    final slots = await VersionRegistry(os).installedSlots();
    expect(slots.map((s) => s.version.toString()), ['8.4.15']);
    expect(slots.single.record!.kind, SlotKind.linked);
  });

  test('a version mismatch is a usage error', () async {
    fakePhp(folder, '8.3.9');

    final code = await run(['link', '8.4', folder]);

    expect(code, ExitCode.usageError);
    expect(console.errors.last, 'That folder has PHP 8.3.9, not 8.4');
    expect(await os.isSymLink(p.join(versions, '8.4')), isFalse);
  });

  test('a folder without php is a usage error', () async {
    final code = await run(['link', '8.4', folder]);

    expect(code, ExitCode.usageError);
    expect(console.errors.last, contains('No php binary found'));
  });

  test('a full patch is a usage error', () async {
    fakePhp(folder, '8.4.15');
    expect(await run(['link', '8.4.15', folder]), ExitCode.usageError);
  });

  test('a filled slot is refused', () async {
    fakePhp(folder, '8.4.15');
    Directory(p.join(versions, '8.4')).createSync();

    final code = await run(['link', '8.4', folder]);

    expect(code, ExitCode.generalError);
    expect(console.errors.last, contains('8.4 is installed'));
    expect(File(p.join(versions, '8.4.pvm-link.json')).existsSync(), isFalse);
  });

  test('uninstall removes the link and record, not the folder', () async {
    fakePhp(folder, '8.4.15');
    await run(['link', '8.4', folder]);

    final code = await run(['uninstall', '8.4', '--yes']);

    expect(code, ExitCode.success);
    expect(await os.isSymLink(p.join(versions, '8.4')), isFalse);
    expect(File(p.join(versions, '8.4.pvm-link.json')).existsSync(), isFalse);
    expect(File(p.join(folder, 'precious.txt')).readAsStringSync(), 'keep me');
  });

  test('installedLabel shows the linked slot as 8.4 (8.4.15)', () async {
    fakePhp(folder, '8.4.15');
    await run(['link', '8.4', folder]);

    expect(
      await installedLabel(PhpVersion(8, 4), p.join(versions, '8.4')),
      '8.4 (8.4.15)',
    );
  });
}
