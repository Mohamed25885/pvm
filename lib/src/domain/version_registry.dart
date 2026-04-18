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

    final versionStrings = _osManager.getAvailableVersions(path);
    final versions = <PhpVersion>[];

    for (final versionStr in versionStrings) {
      try {
        versions.add(PhpVersion.parse(versionStr));
      } on InvalidVersionFormatException {
        // Skip directories with invalid version names
      }
    }

    // Sort descending (newest first)
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
