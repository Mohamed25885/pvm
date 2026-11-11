import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../core/process_manager.dart';
import '../../domain/exceptions/extension_load_exception.dart';
import '../slot_ini.dart';

export '../../domain/exceptions/extension_load_exception.dart';

class ExtensionArtifact {
  static final _name = RegExp(r'^[a-z0-9_]+$');

  /// Rejects names that could escape a URL or path. Call before using [name].
  static void validateName(String name) {
    if (!_name.hasMatch(name)) {
      throw UsageException(
        'Invalid extension name "$name".',
        'Use a-z, 0-9 and _.',
      );
    }
  }
}

/// True when [binary] exports `zend_extension_entry` (a Zend extension).
/// Streams the file; a match may span chunk boundaries.
Future<bool> exportsZendExtension(File binary) async {
  const needle = 'zend_extension_entry';
  var tail = <int>[];
  await for (final chunk in binary.openRead()) {
    final window = [...tail, ...chunk];
    if (_indexOf(window, needle.codeUnits) >= 0) return true;
    tail = window.sublist(
      window.length < needle.length - 1 ? 0 : window.length - needle.length + 1,
    );
  }
  return false;
}

int _indexOf(List<int> h, List<int> n) {
  for (var i = 0; i + n.length <= h.length; i++) {
    var j = 0;
    while (j < n.length && h[i + j] == n[j]) {
      j++;
    }
    if (j == n.length) return i;
  }
  return -1;
}

/// Runs `php -m` with the slot's ini and throws unless [ext] is listed.
Future<void> checkLoads(
  IProcessManager pm,
  String php,
  SlotIni ini,
  String ext,
) async {
  final inv = ini.childInvocation();
  final r = await pm.runCaptured(
    ProcessSpec(
      executable: php,
      arguments: [...inv.args, '-m'],
      environment: inv.env,
    ),
  );
  final listed = r.stdout
      .split('\n')
      .any((l) => l.trim().toLowerCase() == ext.toLowerCase());
  if (listed) return;
  final err = r.stderr.trim();
  throw ExtensionLoadException(ext, err.isNotEmpty ? err : r.stdout.trim());
}

/// Copies a built extension into the slot, enables it, confirms PHP loads it,
/// and undoes everything (restoring any previous build) on failure.
class ExtensionInstallTxn {
  final IProcessManager pm;
  final String php;

  ExtensionInstallTxn(this.pm, this.php);

  Future<void> commit(
    File built,
    String extensionDir,
    SlotIni ini,
    String ext,
  ) async {
    await Directory(extensionDir).create(recursive: true);
    final target = File(
      p.join(extensionDir, extensionFileName(ini.platform, ext)),
    );
    final backup = File('${target.path}.pvm-backup');
    final hadOld = await target.exists();
    if (hadOld) await target.copy(backup.path);
    try {
      await built.copy(target.path);
      await ini.enable(ext, zend: await exportsZendExtension(target));
      await checkLoads(pm, php, ini, ext);
      if (hadOld) await backup.delete();
    } catch (_) {
      await ini.remove(ext);
      if (hadOld) {
        await backup.rename(target.path);
      } else if (await target.exists()) {
        await target.delete();
      }
      rethrow;
    }
  }
}
