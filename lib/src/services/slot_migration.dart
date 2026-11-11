import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/os_manager.dart';
import '../domain/exceptions.dart';
import '../domain/install_record.dart';
import '../domain/php_version.dart';
import '../domain/version_registry.dart';

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

    // Folder name, and the version `pvm uninstall` knows it by (the record's
    // patch when there is one, as in `VersionRegistry.installedSlots`).
    final bySlot = <String, List<({PhpVersion name, PhpVersion shown})>>{};
    for (final dir in root.listSync().whereType<Directory>()) {
      final PhpVersion v;
      try {
        v = PhpVersion.parse(p.basename(dir.path));
      } on InvalidVersionFormatException {
        continue; // .staging-*, .old-*, tmp, ...
      }
      InstallRecord? record;
      try {
        record = await InstallRecord.readFrom(dir.path);
      } catch (_) {
        record = null;
      }
      final shown = VersionRegistry.recordedVersion(record) ?? v;
      bySlot.putIfAbsent(v.slot, () => []).add((name: v, shown: shown));
    }

    final globalLink = p.join(_homeDirectory, PvmConstants.pvmDirName);
    for (final MapEntry(key: slot, value: found) in bySlot.entries) {
      final legacy = [
        for (final f in found)
          if (f.name.hasPatch) f.name,
      ];
      if (legacy.isEmpty) continue;
      if (found.length > 1) {
        found.sort((a, b) => a.shown.compareTo(b.shown));
        // Suggest a legacy folder: uninstall accepts its full patch exactly.
        final remove = found.firstWhere((f) => f.name.hasPatch).shown;
        conflicts.add(slot);
        messages.add(
          'Two patches of $slot are installed '
          '(${found.map((f) => f.shown).join(', ')}). '
          'Remove one with: pvm uninstall $remove',
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
