import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/services/slot_ini.dart';

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

  test('windows-zip slot: scan dir only', () {
    final i = SlotIni(
      slot,
      _record(SlotKind.windowsZip),
      WindowsPlatformInfo(),
    ).childInvocation();
    expect(i.args, isEmpty);
    expect(i.env, {'PHP_INI_SCAN_DIR': p.join(slot, 'conf.d')});
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
    tearDown(() => tmp.deleteSync(recursive: true));

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

    test('windows enable writes php_<ext>.dll path', () async {
      final ini = SlotIni(
        tmp.path,
        _record(SlotKind.windowsZip, extDir: p.join(tmp.path, 'ext')),
        WindowsPlatformInfo(),
      );
      await ini.enable('mbstring', zend: false);
      expect(
        File(p.join(ini.confDir, '50-mbstring.ini')).readAsStringSync(),
        'extension=${p.join(tmp.path, 'ext', 'php_mbstring.dll')}\n',
      );
    });
  });
}
