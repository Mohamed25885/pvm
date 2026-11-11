import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/php_layout.dart';
import '../core/platform_info.dart';
import '../core/process_manager.dart';
import '../domain/exceptions/probe_exception.dart';
import '../domain/install_record.dart';
import '../domain/version_registry.dart';

/// What a version folder's own `php` reported about itself.
class ProbeResult {
  final String version;
  final bool zts;
  final String arch;
  final String apiNo;
  final String? phpConfig;
  final String? prefix;
  final String extensionDir;
  final bool writable;
  final String? vsVersion;

  const ProbeResult({
    required this.version,
    required this.zts,
    required this.arch,
    required this.apiNo,
    required this.extensionDir,
    required this.writable,
    this.phpConfig,
    this.prefix,
    this.vsVersion,
  });
}

/// Asks a version folder's `php` what it is. Callers store the result in the
/// slot's install record; nothing re-probes afterwards except [backfill].
class FolderProbe {
  // `-n` keeps a broken php.ini from breaking the probe.
  static const _script =
      "ob_start();phpinfo(INFO_GENERAL);\$i=ob_get_clean();"
      "preg_match('/PHP Extension Build\\s*=>\\s*(.+)/',\$i,\$m);"
      "echo json_encode(['v'=>PHP_VERSION,'zts'=>(bool)PHP_ZTS,"
      "'arch'=>php_uname('m'),'ext'=>PHP_EXTENSION_DIR,"
      "'build'=>trim(\$m[1]??'')]);";

  final IProcessManager _pm;
  final PlatformInfo _platform;

  FolderProbe(this._pm, this._platform);

  Future<ProbeResult> probe(String folder) async {
    final layout = PhpLayout.forPlatform(_platform);
    final php = layout.phpExecutable(folder);
    if (!File(php).existsSync()) {
      throw ProbeException('No php binary found in $folder (expected $php)');
    }
    final CapturedProcessResult run;
    try {
      run = await _pm.runCaptured(
        ProcessSpec(executable: php, arguments: ['-n', '-r', _script]),
      );
    } on Exception catch (e) {
      // A php that cannot even start is a probe failure, so R12 can warn.
      throw ProbeException('Could not run php in $folder: $e');
    }
    if (run.exitCode != 0) {
      throw ProbeException(
        'php in $folder exited with ${run.exitCode}: ${run.stderr.trim()}',
      );
    }
    final String build, version, rawArch, reportedExt;
    final bool zts;
    try {
      final j = jsonDecode(run.stdout.trim()) as Map<String, dynamic>;
      build = j['build'] as String;
      version = j['v'] as String;
      rawArch = j['arch'] as String;
      reportedExt = j['ext'] as String;
      zts = j['zts'] as bool;
    } catch (_) {
      throw ProbeException('Could not parse probe output from php in $folder');
    }
    final api = RegExp(r'API(\d+)').firstMatch(build)?.group(1);
    if (api == null) {
      throw ProbeException('php in $folder reported no API number: "$build"');
    }
    // With -n, Windows reports the compiled default, not this slot's folder.
    final extDir = layout.binSubdirectory.isEmpty
        ? p.join(folder, 'ext')
        : reportedExt;

    String? phpConfig;
    String? prefix;
    if (layout.binSubdirectory.isNotEmpty) {
      final bin = layout.binDirectory(folder);
      final minor = version.split('.').take(2).join('.');
      for (final name in ['php-config', 'php-config$minor']) {
        if (File(p.join(bin, name)).existsSync()) {
          phpConfig = p.join(bin, name);
          break;
        }
      }
      if (phpConfig != null) {
        final r = await _pm.runCaptured(
          ProcessSpec(executable: phpConfig, arguments: ['--prefix']),
        );
        if (r.exitCode == 0) prefix = r.stdout.trim();
      }
    }

    return ProbeResult(
      version: version,
      zts: zts,
      arch: _normalizeArch(rawArch),
      apiNo: api,
      phpConfig: phpConfig,
      prefix: prefix,
      extensionDir: extDir,
      writable: _isWritable(extDir),
      vsVersion: RegExp(r'VS\d+').firstMatch(build)?.group(0),
    );
  }

  /// A record without probe data (a v2.1.0 schema 1 record: no `apiNo`) of
  /// a PVM-owned slot, filled from the slot's own php and saved (R29). Any
  /// other record, or a failed probe, comes back unchanged. Schema 1 records
  /// were only written on Windows, so their default kind stays.
  Future<InstallRecord> backfill(String slotPath, InstallRecord record) async {
    if (record.apiNo.isNotEmpty || record.kind == SlotKind.linked) {
      return record;
    }
    final ProbeResult r;
    try {
      r = await probe(slotPath);
    } catch (_) {
      return record;
    }
    final filled = record.copyWith(
      zts: r.zts,
      arch: r.arch,
      apiNo: r.apiNo,
      phpConfig: r.phpConfig,
      prefix: r.prefix,
      extensionDir: r.extensionDir,
      writable: r.writable,
      vsVersion: r.vsVersion,
    );
    await VersionRegistry.writeSlotRecord(slotPath, filled);
    return filled;
  }

  static String _normalizeArch(String raw) {
    final a = raw.toLowerCase();
    if (const {'amd64', 'x86_64', 'x64'}.contains(a)) return 'x64';
    if (const {'i386', 'i486', 'i586', 'i686', 'x86'}.contains(a)) return 'x86';
    if (const {'aarch64', 'arm64'}.contains(a)) return 'arm64';
    return a;
  }

  bool _isWritable(String dir) {
    if (!Directory(dir).existsSync()) return false;
    try {
      File(p.join(dir, '.pvm-write-test'))
        ..writeAsStringSync('')
        ..deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
