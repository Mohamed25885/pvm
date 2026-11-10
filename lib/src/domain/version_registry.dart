import 'package:path/path.dart' as p;

import '../core/os_manager.dart';
import 'exceptions.dart';
import 'install_record.dart';
import 'php_version.dart';

/// One installed slot (`versions/<X.Y>`, or a legacy `versions/<X.Y.Z>`
/// awaiting migration).
class InstalledSlot {
  /// The record's full patch when it has one, else the folder name.
  final PhpVersion version;
  final String path;
  final InstallRecord? record;

  const InstalledSlot(this.version, this.path, this.record);
}

/// Manages available PHP versions in the versions directory.
class VersionRegistry {
  final IOSManager _osManager;

  VersionRegistry(this._osManager);

  /// Every slot, newest first. Skips names that are not versions
  /// (`.staging-*`, `.old-*`, `tmp`).
  Future<List<InstalledSlot>> installedSlots() async {
    final root = _osManager.phpVersionsPath;
    if (!await _osManager.directoryExists(root)) return [];

    final slots = <InstalledSlot>[];
    for (final name in _osManager.getAvailableVersions(root)) {
      final PhpVersion parsed;
      try {
        parsed = PhpVersion.parse(name);
      } on InvalidVersionFormatException {
        continue;
      }
      final path = p.join(root, name);
      InstallRecord? record;
      try {
        record = await InstallRecord.readFrom(path);
      } catch (_) {
        record = null; // Unreadable: `pvm doctor --verify` reports it.
      }
      slots.add(
        InstalledSlot(_recordedVersion(record) ?? parsed, path, record),
      );
    }
    slots.sort((a, b) => b.version.compareTo(a.version));
    return slots;
  }

  static PhpVersion? _recordedVersion(InstallRecord? record) {
    if (record == null) return null;
    try {
      return PhpVersion.parse(record.version);
    } on InvalidVersionFormatException {
      return null;
    }
  }

  /// Get all installed PHP versions, sorted newest first.
  Future<List<PhpVersion>> getInstalledVersions() async => [
    for (final s in await installedSlots()) s.version,
  ];

  /// Parses directory names into versions, newest first, silently skipping
  /// folders that are not versions (e.g. `tmp`, `8.3-old`).
  static List<PhpVersion> parseVersionNames(Iterable<String> names) {
    final versions = <PhpVersion>[];
    for (final name in names) {
      try {
        versions.add(PhpVersion.parse(name));
      } on InvalidVersionFormatException {
        // Not a version directory.
      }
    }
    versions.sort((a, b) => b.compareTo(a));
    return versions;
  }

  /// Check if a specific version is installed.
  Future<bool> isInstalled(PhpVersion version) async {
    final sourcePath = getVersionPath(version);
    return await _osManager.directoryExists(sourcePath);
  }

  /// The slot directory for [version]: `versions/<X.Y>`.
  String getVersionPath(PhpVersion version) {
    return p.join(_osManager.phpVersionsPath, version.slot);
  }
}
