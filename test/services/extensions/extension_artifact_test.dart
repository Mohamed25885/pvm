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
import '../../support/temp_dir.dart';

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
  tearDown(() => deleteTempSync(tmp));

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

    test('finds a marker split into 1-3 byte chunks', () async {
      final all = [0, 1, ...marker, 2];
      for (final n in [1, 2, 3]) {
        final chunks = [
          for (var i = 0; i < all.length; i += n)
            all.sublist(i, i + n > all.length ? all.length : i + n),
        ];
        expect(await streamHasZendMarker(Stream.fromIterable(chunks)), isTrue);
      }
      expect(await streamHasZendMarker(Stream.value([1, 2, 3])), isFalse);
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

    test('failed reinstall restores an enabled ini byte-identical', () async {
      Directory(ini.confDir).createSync(recursive: true);
      final live = File(p.join(ini.confDir, iniName))
        ..writeAsStringSync('zend_extension=/old/x.so\n; mine');
      await expectLater(
        ExtensionInstallTxn(
          php('core\n'),
          'php',
        ).commit(built, extDir, ini, 'xdebug'),
        throwsA(isA<ExtensionLoadException>()),
      );
      expect(live.readAsStringSync(), 'zend_extension=/old/x.so\n; mine');
    });

    test('a reinstall keeps a disabled ini disabled and checks the build '
        'with -d', () async {
      built.writeAsBytesSync([...marker]);
      Directory(ini.confDir).createSync(recursive: true);
      final off = File(p.join(ini.confDir, '$iniName.disabled'))
        ..writeAsStringSync('zend_extension=/old.so\nxdebug.mode=debug\n');
      final pm = php('[Zend Modules]\nXdebug\n');
      await ExtensionInstallTxn(pm, 'php').commit(built, extDir, ini, 'xdebug');
      final so = p.join(extDir, 'xdebug.so');
      expect(off.readAsStringSync(), 'zend_extension=$so\nxdebug.mode=debug\n');
      expect(File(p.join(ini.confDir, iniName)).existsSync(), isFalse);
      expect(
        pm.capturedSpecs.single.arguments,
        containsAllInOrder(['-d', 'zend_extension=$so', '-m']),
      );
    });

    test('windows: a failed install restores php.ini byte-identical', () async {
      final slot = p.join(tmp.path, 'win');
      final win = SlotIni(
        slot,
        InstallRecord(
          version: '8.3.1',
          sourceUrl: 'u',
          archiveSha256: 'a',
          verified: true,
          installedAt: DateTime.utc(2026),
          files: const {},
          extensionDir: extDir,
        ),
        WindowsPlatformInfo(),
      );
      final phpIni = File(p.join(slot, 'php.ini'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([...'a=1\r\n'.codeUnits, 0xE9]);
      await expectLater(
        ExtensionInstallTxn(
          php('core\n'),
          'php',
        ).commit(built, extDir, win, 'xdebug'),
        throwsA(isA<ExtensionLoadException>()),
      );
      expect(phpIni.readAsBytesSync(), [...'a=1\r\n'.codeUnits, 0xE9]);
    });

    test('failed reinstall restores a disabled ini as .disabled', () async {
      Directory(ini.confDir).createSync(recursive: true);
      final off = File(p.join(ini.confDir, '$iniName.disabled'))
        ..writeAsStringSync('extension=/old.so\n');
      await expectLater(
        ExtensionInstallTxn(
          php('core\n'),
          'php',
        ).commit(built, extDir, ini, 'xdebug'),
        throwsA(isA<ExtensionLoadException>()),
      );
      expect(off.readAsStringSync(), 'extension=/old.so\n');
      expect(File(p.join(ini.confDir, iniName)).existsSync(), isFalse);
    });

    test(
      'a throwing ini.remove still restores the file, original error',
      () async {
        Directory(extDir).createSync(recursive: true);
        final old = File(p.join(extDir, 'xdebug.so'))..writeAsBytesSync([9]);
        await expectLater(
          ExtensionInstallTxn(
            php('core\n'),
            'php',
          ).commit(built, extDir, _BadRemove(ini), 'xdebug'),
          throwsA(isA<ExtensionLoadException>()),
        );
        expect(old.readAsBytesSync(), [9]);
        expect(Directory(extDir).listSync().length, 1);
      },
    );

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

class _BadRemove extends SlotIni {
  _BadRemove(SlotIni o) : super(o.slotDir, o.record, o.platform);
  @override
  Future<void> remove(String ext) => throw StateError('remove failed');
}
