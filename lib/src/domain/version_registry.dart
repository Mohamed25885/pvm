import 'package:path/path.dart' as p;

import '../core/os_manager.dart';
import 'exceptions.dart';
import 'php_version.dart';

/// Manages available PHP versions in the versions directory.
class VersionRegistry {
  final IOSManager _osManager;

  VersionRegistry(this._osManager);

  /// Get all installed PHP versions, sorted newest first.
  Future<List<PhpVersion>> getInstalledVersions() async {
    final path = _osManager.phpVersionsPath;
    if (!await _osManager.directoryExists(path)) {
      return [];
    }

    return parseVersionNames(_osManager.getAvailableVersions(path));
  }

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

  /// Get the installation directory for a version.
  String getVersionPath(PhpVersion version) {
    return p.join(_osManager.phpVersionsPath, version.toString());
  }
}
