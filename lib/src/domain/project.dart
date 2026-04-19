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

  File get phpVersionFile =>
      File(p.join(rootDirectory.path, PvmConstants.phpVersionFileName));

  File get gitignoreFile =>
      File(p.join(rootDirectory.path, PvmConstants.gitignoreFileName));

  Directory get pvmDirectory =>
      Directory(p.join(rootDirectory.path, PvmConstants.pvmDirName));

  /// Read configured version from .php-version file.
  /// Returns null if file doesn't exist.
  /// Throws [ProjectConfigurationException] if file contains invalid data.
  Future<PhpVersion?> getConfiguredVersion() async {
    if (!await phpVersionFile.exists()) {
      return null;
    }

    final raw = await phpVersionFile.readAsString();
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

  /// Write version to .php-version file in JSON format.
  Future<void> setConfiguredVersion(PhpVersion version) async {
    final data = {'version': version.toString()};
    await phpVersionFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  /// Check if project has an active PHP version (.pvm directory exists).
  Future<bool> hasActiveVersion() async {
    return await pvmDirectory.exists();
  }

  /// Find project root by walking up from current directory.
  /// Returns project at current directory if no .php-version found.
  static Future<Project> findFromCurrentDirectory() async {
    return findFromPath(Directory.current.path);
  }

  /// Find project root by walking up from specified path.
  static Future<Project> findFromPath(String startPath) async {
    var current = Directory(startPath);

    while (true) {
      final versionFile = File(
        p.join(current.path, PvmConstants.phpVersionFileName),
      );

      if (await versionFile.exists()) {
        return Project(current);
      }

      if (current.parent.path == current.path) {
        break; // Reached filesystem root
      }

      current = current.parent;
    }

    // No .php-version found, use start path as root
    return Project(Directory(startPath));
  }
}
