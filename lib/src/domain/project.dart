import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import 'exceptions.dart';
import 'php_version.dart';

/// Represents a PHP project with version configuration.
class Project {
  final Directory rootDirectory;

  Project(this.rootDirectory);

  File get pvmrcFile =>
      File(p.join(rootDirectory.path, PvmConstants.pvmrcFileName));

  File get gitignoreFile =>
      File(p.join(rootDirectory.path, PvmConstants.gitignoreFileName));

  Directory get pvmDirectory =>
      Directory(p.join(rootDirectory.path, PvmConstants.pvmDirName));

  /// Read configured version from `.pvmrc` file.
  /// Returns null if file doesn't exist.
  /// Throws [ProjectConfigurationException] if file contains invalid data.
  Future<PhpVersion?> getConfiguredVersion() async {
    if (!await pvmrcFile.exists()) {
      return null;
    }

    final raw = await pvmrcFile.readAsString();
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    // Try JSON format first: {"version": "8.2"}
    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      final versionStr = json['version'] as String?;
      if (versionStr != null) {
        return PhpVersion.parse(versionStr);
      }
    } catch (_) {
      // Not JSON, treat as plain text
    }

    // Plain text format: "8.2"
    return PhpVersion.parse(trimmed);
  }

  /// Write version to `.pvmrc` file in JSON format.
  Future<void> setConfiguredVersion(PhpVersion version) async {
    final data = {'version': version.toString()};
    await pvmrcFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  /// Check if project has an active PHP version (.pvm directory exists).
  Future<bool> hasActiveVersion() async {
    return await pvmDirectory.exists();
  }

  /// Find project root by walking up from current directory.
  static Future<Project> findFromCurrentDirectory() async {
    return findFromPath(Directory.current.path);
  }

  /// Find project root by walking up from specified path.
  ///
  /// 1. If `.pvmrc` exists → root is that directory
  /// 2. Else if `.pvm/` exists → root is that directory
  /// 3. Else → root is [startPath]
  static Future<Project> findFromPath(String startPath) async {
    var current = Directory(startPath);
    final userProfile =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    final normalizedHome = userProfile != null
        ? p.normalize(userProfile)
        : null;

    while (true) {
      final pvmrc = File(p.join(current.path, PvmConstants.pvmrcFileName));
      if (await pvmrc.exists()) {
        return Project(current);
      }

      final pvmDir = Directory(p.join(current.path, PvmConstants.pvmDirName));
      final isGlobalHomeSlot =
          normalizedHome != null && p.normalize(current.path) == normalizedHome;
      if (await pvmDir.exists() && !isGlobalHomeSlot) {
        return Project(current);
      }

      if (current.parent.path == current.path) {
        break; // Reached filesystem root
      }

      current = current.parent;
    }

    return Project(Directory(startPath));
  }
}
