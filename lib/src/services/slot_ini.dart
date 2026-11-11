import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/platform_info.dart';
import '../domain/install_record.dart';

/// The ini of one PVM-owned slot. PVM hands it only to the PHP it starts
/// itself ([childInvocation]), never to the environment users' shells inherit.
class SlotIni {
  final String slotDir;
  final InstallRecord record;
  final PlatformInfo platform;

  SlotIni(this.slotDir, this.record, this.platform);

  /// Where the slot's `conf.d` lives. A linked slot is the user's folder, so
  /// PVM has none there.
  String get confDir {
    switch (record.kind) {
      case SlotKind.linked:
        throw StateError('A linked slot has no PVM-owned conf.d');
      case SlotKind.windowsZip:
        return p.join(slotDir, 'conf.d');
      case SlotKind.static:
      case SlotKind.source:
        return p.join(slotDir, 'etc', 'conf.d');
    }
  }

  File _file(String ext, {bool disabled = false}) =>
      File(p.join(confDir, '50-$ext.ini${disabled ? '.disabled' : ''}'));

  Future<void> enable(String ext, {required bool zend}) async {
    final name = platform.osType == 'windows' ? 'php_$ext.dll' : '$ext.so';
    final path = p.join(record.extensionDir, name);
    await Directory(confDir).create(recursive: true);
    await _file(
      ext,
    ).writeAsString('${zend ? 'zend_extension' : 'extension'}=$path\n');
    final off = _file(ext, disabled: true);
    if (await off.exists()) await off.delete();
  }

  Future<void> disable(String ext) async {
    final f = _file(ext);
    if (await f.exists()) await f.rename('${f.path}.disabled');
  }

  Future<void> remove(String ext) async {
    for (final f in [_file(ext), _file(ext, disabled: true)]) {
      if (await f.exists()) await f.delete();
    }
  }

  /// Arguments (before the user's) and environment for the child PHP only.
  /// Source builds compile their paths in; linked slots use the system ini.
  ({List<String> args, Map<String, String> env}) childInvocation() {
    switch (record.kind) {
      case SlotKind.static:
        return (
          args: ['-c', p.join(slotDir, 'etc', 'php.ini')],
          env: {'PHP_INI_SCAN_DIR': confDir},
        );
      case SlotKind.windowsZip:
        return (args: [], env: {'PHP_INI_SCAN_DIR': confDir});
      case SlotKind.source:
      case SlotKind.linked:
        return (args: [], env: {});
    }
  }
}
