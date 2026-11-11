import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/platform_info.dart';
import '../domain/install_record.dart';

/// The file name PHP loads for [ext] on [platform].
String extensionFileName(PlatformInfo platform, String ext) =>
    platform.osType == 'windows' ? 'php_$ext.dll' : '$ext.so';

/// The ini of one PVM-owned slot. PVM hands it only to the PHP it starts
/// itself ([childInvocation]), never to the environment users' shells inherit.
///
/// A windows-zip slot keeps its extension lines in a managed block of its
/// own `php.ini` (R31): php.exe always reads that file, so IDEs and plain
/// `php` load them too. Other slots use one `50-<ext>.ini` per extension.
class SlotIni {
  final String slotDir;
  final InstallRecord record;
  final PlatformInfo platform;

  static const blockBegin = '; BEGIN pvm extensions (managed by pvm)';
  static const blockEnd = '; END pvm extensions';
  static const _off = ';pvm-disabled: ';

  /// [confDir] overrides where the ini files go: a linked slot's own scan dir.
  SlotIni(this.slotDir, this.record, this.platform, {this._confDir});

  final String? _confDir;

  bool get _inPhpIni => _confDir == null && record.kind == SlotKind.windowsZip;

  File get _phpIni => File(p.join(slotDir, 'php.ini'));

  /// Where the slot's `conf.d` lives. A linked slot is the user's folder, so
  /// it has one only when given ([SlotIni.new]'s `confDir`); a windows-zip
  /// slot uses its php.ini instead.
  String get confDir {
    if (_confDir != null) return _confDir;
    switch (record.kind) {
      case SlotKind.linked:
        throw StateError('A linked slot has no PVM-owned conf.d');
      case SlotKind.windowsZip:
        throw StateError('A windows-zip slot keeps extensions in php.ini');
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
    if (_inPhpIni) {
      var enabled = true;
      await _editBlock((lines) {
        final i = _lineOf(lines, ext);
        if (i < 0) {
          lines.add(line);
        } else {
          enabled = !lines[i].startsWith(_off);
          lines[i] = enabled ? line : '$_off$line';
        }
        return true;
      });
      return enabled;
    }
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
    if (_inPhpIni) {
      return _editBlock((lines) {
        final i = _lineOf(lines, ext);
        if (i < 0 || lines[i].startsWith(_off)) return false;
        lines[i] = '$_off${lines[i]}';
        return true;
      });
    }
    final f = _file(ext);
    if (await f.exists()) await f.rename('${f.path}.disabled');
  }

  Future<void> remove(String ext) async {
    if (_inPhpIni) {
      return _editBlock((lines) {
        final i = _lineOf(lines, ext);
        if (i >= 0) lines.removeAt(i);
        return i >= 0;
      });
    }
    for (final f in [_file(ext), _file(ext, disabled: true)]) {
      if (await f.exists()) await f.delete();
    }
  }

  /// Saves where [ext] is registered now; the returned function puts exactly
  /// that back (a windows-zip slot: its whole php.ini).
  Future<Future<void> Function()> snapshot(String ext) async {
    final files = _inPhpIni
        ? [_phpIni]
        : [_file(ext), _file(ext, disabled: true)];
    File? had;
    List<int>? bytes;
    for (final f in files) {
      if (await f.exists()) {
        had = f;
        bytes = await f.readAsBytes();
        break;
      }
    }
    return () async {
      for (final f in files) {
        if (await f.exists()) await f.delete();
      }
      if (had != null) await had.writeAsBytes(bytes!);
    };
  }

  /// The index in [lines] of [ext]'s load line (enabled or disabled), or -1.
  int _lineOf(List<String> lines, String ext) {
    final name = extensionFileName(platform, ext).toLowerCase();
    return lines.indexWhere((l) {
      final m = RegExp('^(?:$_off)?(?:zend_)?extension=(.*)\$').firstMatch(l);
      return m != null &&
          m[1]!.split(RegExp(r'[\\/]')).last.toLowerCase() == name;
    });
  }

  /// Rewrites the managed block of the slot's php.ini (creating either);
  /// [edit] changes its lines and says whether to write. Bytes outside the
  /// block are copied through untouched.
  Future<void> _editBlock(bool Function(List<String> lines) edit) async {
    final f = _phpIni;
    final bytes = await f.exists() ? await f.readAsBytes() : <int>[];
    final text = latin1.decode(bytes); // one char per byte: indexes are offsets
    final b = text.indexOf(blockBegin);
    final e = b < 0 ? -1 : text.indexOf(blockEnd, b);
    final List<int> head, tail;
    final List<String> lines;
    if (e < 0) {
      head = [...bytes, if (bytes.isNotEmpty && bytes.last != 0x0A) 0x0A];
      tail = const [];
      lines = [];
    } else {
      var stop = e + blockEnd.length;
      if (text.startsWith('\r\n', stop)) {
        stop += 2;
      } else if (text.startsWith('\n', stop)) {
        stop += 1;
      }
      head = bytes.sublist(0, b);
      tail = bytes.sublist(stop);
      lines = [
        for (final l
            in utf8
                .decode(
                  bytes.sublist(b + blockBegin.length, e),
                  allowMalformed: true,
                )
                .split('\n'))
          if (l.trim().isNotEmpty) l.trim(),
      ];
    }
    if (!edit(lines)) return;
    await f.parent.create(recursive: true);
    await f.writeAsBytes([
      ...head,
      ...utf8.encode(
        '$blockBegin\n${lines.map((l) => '$l\n').join()}$blockEnd\n',
      ),
      ...tail,
    ]);
  }

  /// Arguments (before the user's) and environment for the child PHP only.
  /// Source builds compile their paths in, php.exe reads the php.ini beside
  /// it, and linked slots use the system ini.
  ({List<String> args, Map<String, String> env}) childInvocation() {
    switch (record.kind) {
      case SlotKind.static:
        return (
          args: ['-c', p.join(slotDir, 'etc', 'php.ini')],
          env: {'PHP_INI_SCAN_DIR': confDir},
        );
      case SlotKind.windowsZip:
      case SlotKind.source:
      case SlotKind.linked:
        return (args: [], env: {});
    }
  }
}
