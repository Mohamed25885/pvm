import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/services/extensions/extension_artifact.dart';
import 'package:pvm/src/services/slot_ini.dart';

import '../fake_process_manager.dart';

void main() {
  late Directory tmp;
  late SlotIni ini;
  late String extDir;
  late File built;
  final marker = 'zend_extension_entry'.codeUnits;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pvm-ext-txn');
    extDir = p.join(tmp.path, 'ext');
    ini = SlotIni(
      p.join(tmp.path, 'slot'),
      InstallRecord(
        version: '8.3.1',
        sourceUrl: 'u',
        archiveSha256: 'a',
        verified: true,
        installedAt: DateTime.utc(2026),
        files: const {},
        kind: SlotKind.static,
        extensionDir: extDir,
      ),
      LinuxPlatformInfo(),
    );
    built = File(p.join(tmp.path, 'built.bin'))..writeAsBytesSync([1, 2, 3]);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  FakeProcessManager php(String stdout, {String stderr = ''}) =>
      FakeProcessManager()
        ..capturedResults['php'] = CapturedProcessResult(
          stdout: stdout,
          stderr: stderr,
          exitCode: 0,
        );

  group('exportsZendExtension', () {
    test('true with the marker, false without', () async {
      final yes = File(p.join(tmp.path, 'y'))
        ..writeAsBytesSync([0, 9, ...marker, 7]);
      expect(await exportsZendExtension(yes), isTrue);
      expect(await exportsZendExtension(built), isFalse);
    });

    test('finds a marker spanning chunk boundaries', () async {
      for (final at in [65536 - 5, 65536 - 1, 65536 - 19]) {
        final bytes = List<int>.filled(at, 0, growable: true)
          ..addAll(marker)
          ..addAll(List.filled(100, 0));
        final f = File(p.join(tmp.path, 'big$at'))..writeAsBytesSync(bytes);
        expect(await exportsZendExtension(f), isTrue, reason: '$at');
      }
    });
  });

  group('checkLoads', () {
    test(
      'passes on a case-insensitive line match and sends ini args/env',
      () async {
        final pm = php('[PHP Modules]\ncore\n\n[Zend Modules]\nXdebug\n');
        await checkLoads(pm, 'php', ini, 'xdebug');
        expect(pm.lastSpec, isNull);
        expect(pm.capturedSpecs.single.arguments.last, '-m');
        expect(pm.capturedSpecs.single.arguments, contains('-c'));
        expect(pm.capturedSpecs.single.environment, ini.childInvocation().env);
      },
    );

    test('throws with stderr when not listed', () async {
      final pm = php('core\n', stderr: ' Unable to load \n');
      expect(
        () => checkLoads(pm, 'php', ini, 'xdebug'),
        throwsA(
          isA<ExtensionLoadException>().having(
            (e) => e.toString(),
            'message',
            contains('Unable to load'),
          ),
        ),
      );
    });

    test('falls back to stdout warnings when stderr is empty', () async {
      final pm = php('Warning: PHP Startup: Unable to load dynamic library\n');
      expect(
        () => checkLoads(pm, 'php', ini, 'xdebug'),
        throwsA(
          isA<ExtensionLoadException>().having(
            (e) => e.toString(),
            'message',
            contains('Unable to load dynamic library'),
          ),
        ),
      );
    });
  });

  group('ExtensionInstallTxn', () {
    final iniName = '50-xdebug.ini';

    test('commit copies, enables as zend and keeps both on success', () async {
      built.writeAsBytesSync([...marker]);
      final pm = php('[Zend Modules]\nXdebug\n');
      await ExtensionInstallTxn(pm, 'php').commit(built, extDir, ini, 'xdebug');
      expect(File(p.join(extDir, 'xdebug.so')).existsSync(), isTrue);
      expect(
        File(p.join(ini.confDir, iniName)).readAsStringSync(),
        'zend_extension=${p.join(extDir, 'xdebug.so')}\n',
      );
    });

    test('load failure removes the copied file and the ini', () async {
      final pm = php('core\n', stderr: 'boom');
      await expectLater(
        ExtensionInstallTxn(pm, 'php').commit(built, extDir, ini, 'xdebug'),
        throwsA(isA<ExtensionLoadException>()),
      );
      expect(File(p.join(extDir, 'xdebug.so')).existsSync(), isFalse);
      expect(File(p.join(ini.confDir, iniName)).existsSync(), isFalse);
    });

    test('load failure restores a pre-existing file', () async {
      Directory(extDir).createSync(recursive: true);
      final old = File(p.join(extDir, 'xdebug.so'))
        ..writeAsBytesSync([9, 9, 9]);
      final pm = php('core\n', stderr: 'boom');
      await expectLater(
        ExtensionInstallTxn(pm, 'php').commit(built, extDir, ini, 'xdebug'),
        throwsA(isA<ExtensionLoadException>()),
      );
      expect(old.readAsBytesSync(), [9, 9, 9]);
      expect(Directory(extDir).listSync().length, 1);
    });
  });

  test('validateName', () {
    ExtensionArtifact.validateName('xdebug');
    ExtensionArtifact.validateName('pdo_mysql2');
    for (final bad in ['../x', 'a/b', 'Xdebug', '', 'a-b']) {
      expect(
        () => ExtensionArtifact.validateName(bad),
        throwsA(isA<UsageException>()),
        reason: bad,
      );
    }
  });
}
