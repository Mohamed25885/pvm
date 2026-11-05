import 'dart:io';

import 'package:path/path.dart' as p;

import '../interfaces/i_environment_configurator.dart';

typedef RunProcess =
    Future<ProcessResult> Function(String executable, List<String> args);

typedef WriteBackup = Future<void> Function(String name, String value);

/// Persists user environment variables on Windows via `HKCU\Environment`.
///
/// Values are written with `reg add` (never `setx`, which truncates values to
/// 1024 characters and silently drops `REG_EXPAND_SZ`). The previous `Path`
/// value is backed up before it is replaced, and the new value is refused if it
/// would drop any existing segment.
class WindowsEnvironmentConfigurator implements IEnvironmentConfigurator {
  static const _key = r'HKCU\Environment';
  static const _expandType = 'REG_EXPAND_SZ';
  static const _plainType = 'REG_SZ';

  final RunProcess _runProcess;
  final WriteBackup _writeBackup;

  WindowsEnvironmentConfigurator({
    RunProcess? runProcess,
    WriteBackup? writeBackup,
  }) : _runProcess = runProcess ?? Process.run,
       _writeBackup = writeBackup ?? _defaultWriteBackup;

  @override
  bool get canPersistEnvironment => true;

  @override
  Future<String?> getUserEnvironmentVariable(String name) async =>
      (await _query(name))?.value;

  @override
  Future<void> setUserEnvironmentVariable(String name, String value) async {
    final existing = await _query(name);
    await _write(name, value, type: existing?.type ?? _typeFor(value));
    await _broadcastSettingChange();
  }

  @override
  Future<String> getPath() async => (await _query('Path'))?.value ?? '';

  @override
  Future<void> ensurePathEntries(List<String> entries) async {
    final existing = await _query('Path');
    final current = existing?.value ?? '';
    final segments = current.isEmpty
        ? <String>[]
        : current.split(';').where((s) => s.trim().isNotEmpty).toList();
    final known = segments.map(_pathKey).toSet();
    final added = <String>[];
    for (final entry in entries) {
      final key = _pathKey(entry);
      if (known.add(key)) added.add(p.normalize(entry));
    }
    if (added.isEmpty) return;

    final updated = [...segments, ...added].join(';');
    _assertNoSegmentLost(current, updated);

    if (current.isNotEmpty) {
      await _writeBackup('Path', current);
    }
    // User Path is REG_EXPAND_SZ by default on Windows; keep whatever it was.
    await _write('Path', updated, type: existing?.type ?? _expandType);
    await _broadcastSettingChange();
  }

  String _pathKey(String segment) => p.normalize(segment.trim()).toLowerCase();

  void _assertNoSegmentLost(String before, String after) {
    final afterKeys = after.split(';').map(_pathKey).toSet();
    final lost = before
        .split(';')
        .where((s) => s.trim().isNotEmpty)
        .where((s) => !afterKeys.contains(_pathKey(s)))
        .toList();
    if (lost.isNotEmpty || after.length < before.length) {
      throw StateError(
        'Refusing to write PATH: existing entries would be lost (${lost.join(';')})',
      );
    }
  }

  String _typeFor(String value) =>
      value.contains('%') ? _expandType : _plainType;

  /// Returns `null` only when the value does not exist. Any other `reg`
  /// failure throws, so a transient error can never be mistaken for an empty
  /// PATH (which would then be overwritten).
  Future<({String type, String value})?> _query(String name) async {
    final result = await _runProcess('reg', ['query', _key, '/v', name]);
    if (result.exitCode != 0) {
      final output = '${result.stdout}\n${result.stderr}'.toLowerCase();
      if (output.contains('unable to find') || output.trim().isEmpty) {
        return null;
      }
      throw Exception('Failed to read $name: ${result.stderr}'.trim());
    }
    final match = RegExp(
      r'^\s*' + RegExp.escape(name) + r'\s+(REG_\w+)\s*(.*)$',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch('${result.stdout}');
    if (match == null) return null;
    return (type: match.group(1)!, value: match.group(2)!.trim());
  }

  Future<void> _write(String name, String value, {required String type}) async {
    final result = await _runProcess('reg', [
      'add',
      _key,
      '/v',
      name,
      '/t',
      type,
      '/d',
      value,
      '/f',
    ]);
    if (result.exitCode != 0) {
      throw Exception('Failed to set $name: ${result.stderr}'.trim());
    }
  }

  /// Notify running applications (Explorer, new terminals) that the user
  /// environment changed. Best-effort.
  Future<void> _broadcastSettingChange() async {
    const script = r'''
Add-Type -Namespace Pvm -Name Native -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);'
$r = [UIntPtr]::Zero
[void][Pvm.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r)
''';
    try {
      await _runProcess('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        script,
      ]);
    } catch (_) {
      // Ignore: new shells still pick up the change after sign-in.
    }
  }

  static Future<void> _defaultWriteBackup(String name, String value) async {
    final base =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final dir = Directory(p.join(base, 'pvm', 'backups'));
    await dir.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    await File(
      p.join(dir.path, '${name.toLowerCase()}-$stamp.txt'),
    ).writeAsString(value);
  }
}
