import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/console.dart';
import '../../core/platform_info.dart';
import '../../core/process_manager.dart';
import '../../domain/install_record.dart';
import '../../domain/php_version.dart';
import '../../domain/version_registry.dart';
import '../../interfaces/i_installer.dart';
import '../slot_ini.dart';
import 'extension_artifact.dart';
import 'pecl_download.dart';

export 'pecl_download.dart'
    show ExtensionUnavailableException, SlotBrokenException;

/// Windows: installs the PECL DLL build matching one slot's record (PHP X.Y,
/// TS/NTS, VS version, arch) through [ExtensionInstallTxn].
class PeclWindowsDll {
  final PlatformInfo _platform;
  final Console _console;
  final IProcessManager _pm;
  final PeclDownloads _downloads;

  PeclWindowsDll({
    required this._platform,
    required this._console,
    required IProcessManager processManager,
    required http.Client client,
    Duration retryDelay = const Duration(seconds: 1),
  }) : _pm = processManager,
       _downloads = PeclDownloads(_platform, _console, client, retryDelay);

  /// Installs the latest stable [ext]: `php_<ext>.dll` into the slot's
  /// extension dir, its other DLLs next to `php.exe`. The caller records the
  /// returned entry in the slot record.
  Future<ExtensionEntry> install(String ext, InstalledSlot slot) async {
    ExtensionArtifact.validateName(ext);
    final x = slot.version.slot;
    final php = p.join(slot.path, 'php.exe');
    final record = slot.record;
    if (record == null || !await File(php).exists()) {
      throw SlotBrokenException(
        'Slot $x is broken (php.exe missing); reinstall it',
      );
    }
    final vs = record.vsVersion;
    if (vs == null) {
      throw ExtensionUnavailableException(
        'PHP $x has no recorded VS version; run: pvm update $x',
      );
    }
    final arch = record.arch;
    if (arch != 'x64' && arch != 'x86') {
      throw ExtensionUnavailableException('PECL has no Windows $arch builds');
    }
    final ts = record.zts ? 'ts' : 'nts';

    final tmp = await Directory.systemTemp.createTemp('pvm-pecl-');
    final added = <File>[];
    try {
      final ver = await _downloads.stableVersion(ext, tmp.path);
      final File zip;
      try {
        _console.print('Downloading $ext $ver...');
        zip = await _downloads.get(
          'https://downloads.php.net/~windows/pecl/releases/$ext/$ver/'
          'php_$ext-$ver-$x-$ts-${vs.toLowerCase()}-$arch.zip',
          tmp.path,
        );
      } on DownloadException catch (e) {
        if (e.statusCode != 404) rethrow;
        throw ExtensionUnavailableException(
          '$ext $ver has no Windows build for PHP $x '
          '${ts.toUpperCase()} $vs $arch',
        );
      }
      final sha = await _downloads.sha256Of(zip);
      final unpacked = p.join(tmp.path, 'unpacked');
      await _downloads.extractZip(zip.path, unpacked);

      final dllName = extensionFileName(_platform, ext);
      final dll = File(p.join(unpacked, dllName));
      if (!await dll.exists()) {
        throw Exception('The $ext zip has no $dllName');
      }
      // Dependency DLLs load from php.exe's folder.
      await for (final e in Directory(unpacked).list()) {
        final name = p.basename(e.path);
        if (e is! File ||
            name == dllName ||
            p.extension(name).toLowerCase() != '.dll') {
          continue;
        }
        final dest = File(p.join(slot.path, name));
        if (await dest.exists()) {
          if (_same(await dest.readAsBytes(), await e.readAsBytes())) continue;
          throw Exception(
            '$name in the $ext zip differs from the one next to php.exe',
          );
        }
        await e.copy(dest.path);
        added.add(dest);
        _console.print('Added $name next to php.exe');
      }

      await ExtensionInstallTxn(_pm, php).commit(
        dll,
        record.extensionDir,
        SlotIni(slot.path, record, _platform),
        ext,
      );
      added.clear(); // committed: keep them
      return ExtensionEntry(
        name: ext,
        version: ver,
        file: dllName,
        sha256: sha,
        verified: false,
      );
    } finally {
      for (final f in added) {
        try {
          await f.delete();
        } catch (_) {}
      }
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void dispose() => _downloads.dispose();
}
