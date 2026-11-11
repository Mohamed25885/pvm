import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/services/slot_ini.dart';
import '../support/temp_dir.dart';

InstallRecord _record(SlotKind kind, {String extDir = '/x/ext'}) =>
    InstallRecord(
      version: '8.3.1',
      sourceUrl: 'u',
      archiveSha256: 'a',
      verified: true,
      installedAt: DateTime.utc(2026),
      files: const {},
      kind: kind,
      extensionDir: extDir,
    );

void main() {
  const slot = '/v/8.3';
  final linux = LinuxPlatformInfo();

  test('static slot', () {
    final i = SlotIni(slot, _record(SlotKind.static), linux).childInvocation();
    expect(i.args, ['-c', p.join(slot, 'etc', 'php.ini')]);
    expect(i.env, {'PHP_INI_SCAN_DIR': p.join(slot, 'etc', 'conf.d')});
  });

  test('source and linked slots pass nothing', () {
    for (final k in [SlotKind.source, SlotKind.linked]) {
      final i = SlotIni(slot, _record(k), linux).childInvocation();
      expect(i.args, isEmpty);
      expect(i.env, isEmpty);
    }
  });

  test('windows-zip slot passes nothing: php.exe reads its own php.ini', () {
    final i = SlotIni(
      slot,
      _record(SlotKind.windowsZip),
      WindowsPlatformInfo(),
    ).childInvocation();
    expect(i.args, isEmpty);
    expect(i.env, isEmpty);
  });

  test('linked confDir throws', () {
    expect(
      () => SlotIni(slot, _record(SlotKind.linked), linux).confDir,
      throwsStateError,
    );
  });

  group('files', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('pvm-slot-ini'));
    tearDown(() => deleteTempSync(tmp));

    test('enable, disable, remove', () async {
      final ini = SlotIni(
        tmp.path,
        _record(SlotKind.static, extDir: p.join(tmp.path, 'ext')),
        linux,
      );
      final f = File(p.join(ini.confDir, '50-xdebug.ini'));
      await ini.enable('xdebug', zend: true);
      expect(
        f.readAsStringSync(),
        'zend_extension=${p.join(tmp.path, 'ext', 'xdebug.so')}\n',
      );

      await ini.disable('xdebug');
      expect(f.existsSync(), false);
      expect(File('${f.path}.disabled').existsSync(), true);

      await ini.remove('xdebug');
      expect(File('${f.path}.disabled').existsSync(), false);
      await ini.remove('xdebug');
      await ini.disable('xdebug');
    });

    test('enable replaces only the load line of an existing ini', () async {
      final ini = SlotIni(
        tmp.path,
        _record(SlotKind.source, extDir: p.join(tmp.path, 'ext')),
        linux,
      );
      final f = File(p.join(ini.confDir, '50-xdebug.ini'))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '; mine\nzend_extension=/old/xdebug.so\nxdebug.mode=debug\n',
        );
      expect(await ini.enable('xdebug', zend: true), isTrue);
      expect(
        f.readAsStringSync(),
        '; mine\nzend_extension=${p.join(tmp.path, 'ext', 'xdebug.so')}\n'
        'xdebug.mode=debug\n',
      );
    });

    test('enable keeps a disabled ini disabled', () async {
      final ini = SlotIni(
        tmp.path,
        _record(SlotKind.source, extDir: p.join(tmp.path, 'ext')),
        linux,
      );
      final off = File(p.join(ini.confDir, '50-xdebug.ini.disabled'))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'zend_extension=/old/xdebug.so\nxdebug.mode=debug\n',
        );
      expect(await ini.enable('xdebug', zend: true), isFalse);
      expect(
        off.readAsStringSync(),
        'zend_extension=${p.join(tmp.path, 'ext', 'xdebug.so')}\n'
        'xdebug.mode=debug\n',
      );
      expect(File(p.join(ini.confDir, '50-xdebug.ini')).existsSync(), isFalse);
    });

    group('windows php.ini block', () {
      late SlotIni ini;
      late File phpIni;
      late String dll;
      const begin = '; BEGIN pvm extensions (managed by pvm)';
      const end = '; END pvm extensions';
      setUp(() {
        ini = SlotIni(
          tmp.path,
          _record(SlotKind.windowsZip, extDir: p.join(tmp.path, 'ext')),
          WindowsPlatformInfo(),
        );
        phpIni = File(p.join(tmp.path, 'php.ini'));
        dll = p.join(tmp.path, 'ext', 'php_xdebug.dll');
      });

      test('a fresh slot gets php.ini with the block', () async {
        expect(await ini.enable('xdebug', zend: true), isTrue);
        expect(
          phpIni.readAsStringSync(),
          '$begin\nzend_extension=$dll\n$end\n',
        );
        expect(Directory(p.join(tmp.path, 'conf.d')).existsSync(), isFalse);
      });

      test('enable, disable, remove keep bytes outside the block', () async {
        // CRLF and a non-UTF-8 byte: copied through untouched.
        final head = [
          ...'memory_limit=1G\r\n; caf'.codeUnits,
          0xE9,
          0x0D,
          0x0A,
        ];
        final tail = '[xdebug]\r\nxdebug.mode=debug\r\n'.codeUnits;
        phpIni.writeAsBytesSync([
          ...head,
          ...'$begin\nextension=C:/old/php_redis.dll\n$end\n'.codeUnits,
          ...tail,
        ]);
        List<int> block(String lines) => [
          ...head,
          ...'$begin\n$lines$end\n'.codeUnits,
          ...tail,
        ];

        await ini.enable('xdebug', zend: true);
        expect(
          phpIni.readAsBytesSync(),
          block('extension=C:/old/php_redis.dll\nzend_extension=$dll\n'),
        );

        await ini.disable('xdebug');
        expect(
          phpIni.readAsBytesSync(),
          block(
            'extension=C:/old/php_redis.dll\n'
            ';pvm-disabled: zend_extension=$dll\n',
          ),
        );

        // Reinstalling keeps it disabled (as the conf.d form does).
        expect(await ini.enable('xdebug', zend: true), isFalse);
        await ini.remove('xdebug');
        expect(
          phpIni.readAsBytesSync(),
          block('extension=C:/old/php_redis.dll\n'),
        );
      });

      test('a php.ini without a block gets one appended', () async {
        phpIni.writeAsStringSync('memory_limit=1G');
        await ini.enable('xdebug', zend: true);
        expect(
          phpIni.readAsStringSync(),
          'memory_limit=1G\n$begin\nzend_extension=$dll\n$end\n',
        );
      });
    });
  });
}
