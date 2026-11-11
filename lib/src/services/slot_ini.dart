import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/platform_info.dart';
import '../domain/install_record.dart';

/// The file name PHP loads for [ext] on [platform].
String extensionFileName(PlatformInfo platform, String ext) =>
    platform.osType == 'windows' ? 'php_$ext.dll' : '$ext.so';

/// The ini of one PVM-owned slot. PVM hands it only to the PHP it starts
/// itself ([childInvocation]), never to the environment users' shells inherit.
class SlotIni {
  final String slotDir;
  final InstallRecord record;
  final PlatformInfo platform;

  /// [confDir] overrides where the ini files go: a linked slot's own scan dir.
  SlotIni(this.slotDir, this.record, this.platform, {this._confDir});

  final String? _confDir;

  /// Where the slot's `conf.d` lives. A linked slot is the user's folder, so
  /// it has one only when given ([SlotIni.new]'s `confDir`).
  String get confDir {
    if (_confDir != null) return _confDir;
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

  /// Points [ext]'s ini at the slot's build. An existing ini keeps its other
  /// lines (settings such as `xdebug.mode`) and its disabled state; only
  /// without one is a new, enabled ini written. True when [ext] is enabled.
  Future<bool> enable(String ext, {required bool zend}) async {
    final line =
        '${zend ? 'zend_extension' : 'extension'}='
        '${p.join(record.extensionDir, extensionFileName(platform, ext))}';
    final on = _file(ext);
    final off = _file(ext, disabled: true);
    if (await on.exists()) {
      await on.writeAsString(_withLoadLine(await on.readAsString(), line));
      if (await off.exists()) await off.delete();
      return true;
    }
    if (await off.exists()) {
      await off.writeAsString(_withLoadLine(await off.readAsString(), line));
      return false;
    }
    await Directory(confDir).create(recursive: true);
    await on.writeAsString('$line\n');
    return true;
  }

  static final _loadLine = RegExp(
    r'^[ \t]*(zend_)?extension[ \t]*=.*$',
    multiLine: true,
  );

  /// [text] with its first load line replaced by [line] (prepended if none).
  static String _withLoadLine(String text, String line) =>
      _loadLine.hasMatch(text)
      ? text.replaceFirst(_loadLine, line)
      : '$line\n$text';

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
