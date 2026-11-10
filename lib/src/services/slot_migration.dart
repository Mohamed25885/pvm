import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/os_manager.dart';
import '../domain/exceptions.dart';
import '../domain/php_version.dart';

class MigrationResult {
  /// Legacy folder names renamed to their minor, e.g. `8.2.28`.
  final List<String> renamed;

  /// Minors left alone because two folders claim them, e.g. `8.2`.
  final List<String> conflicts;

  /// One line per conflict, for the user.
  final List<String> messages;

  const MigrationResult(this.renamed, this.conflicts, this.messages);
}

/// Moves full-patch slots (`versions/8.2.28`) to one slot per minor
/// (`versions/8.2`) and re-points the global `.pvm` link. Local project links
/// can't be enumerated; `pvm current` flags those as stale.
class SlotMigration {
  final IOSManager _os;
  final String _versionsPath;
  final String _homeDirectory;

  SlotMigration(this._os, this._versionsPath, this._homeDirectory);

  Future<MigrationResult> run() async {
    final renamed = <String>[];
    final conflicts = <String>[];
    final messages = <String>[];
    final root = Directory(_versionsPath);
    if (!root.existsSync()) {
      return MigrationResult(renamed, conflicts, messages);
    }

    final bySlot = <String, List<PhpVersion>>{};
    for (final dir in root.listSync().whereType<Directory>()) {
      try {
        final v = PhpVersion.parse(p.basename(dir.path));
        bySlot.putIfAbsent(v.slot, () => []).add(v);
      } on InvalidVersionFormatException {
        // .staging-*, .old-*, tmp, ...
      }
    }

    final globalLink = p.join(_homeDirectory, PvmConstants.pvmDirName);
    for (final MapEntry(key: slot, value: found) in bySlot.entries) {
      final legacy = found.where((v) => v.hasPatch).toList();
      if (legacy.isEmpty) continue;
      if (found.length > 1) {
        found.sort();
        conflicts.add(slot);
        messages.add(
          'Two patches of $slot are installed (${found.join(', ')}). '
          'Remove one with: pvm uninstall ${found.first}',
        );
        continue;
      }

      final from = p.join(_versionsPath, legacy.single.toString());
      final to = p.join(_versionsPath, slot);
      await Directory(from).rename(to);
      renamed.add(legacy.single.toString());

      final target = await _os.readSymLinkTarget(globalLink);
      if (target != null &&
          p.equals(p.normalize(p.join(_homeDirectory, target)), from)) {
        await _os.createSymLink(slot, to, globalLink);
      }
    }
    return MigrationResult(renamed, conflicts, messages);
  }
}
