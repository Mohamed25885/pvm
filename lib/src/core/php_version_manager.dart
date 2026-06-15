import 'dart:io';

import '../domain/php_version.dart';
import '../domain/project.dart';
import 'console.dart';

class PhpVersionManager {
  final Console console;

  PhpVersionManager(this.console);

  /// Read version from `.pvmrc` file.
  /// Returns null if file doesn't exist or is empty.
  /// Throws [InvalidVersionFormatException] on invalid format.
  ///
  /// Delegates to [Project.getConfiguredVersion] to keep a single canonical
  /// reader for the `.pvmrc` file format (JSON or plain text).
  Future<PhpVersion?> readLastUsedVersion({required String rootPath}) async {
    final project = Project(Directory(rootPath));
    return project.getConfiguredVersion();
  }

  /// Write version to `.pvmrc` file in JSON format.
  ///
  /// Delegates to [Project.setConfiguredVersion] for the canonical write path.
  Future<void> writeCurrentVersion({
    required String rootPath,
    required PhpVersion version,
  }) async {
    final project = Project(Directory(rootPath));
    await project.setConfiguredVersion(version);
  }

  /// Prompt user to switch versions (returns true if user confirms).
  /// Default: NO (safe default - user must explicitly type 'y').
  Future<bool> promptMismatch({
    required PhpVersion currentVersion,
    required PhpVersion requestedVersion,
  }) async {
    return console.confirm(
      'Detected .pvmrc contains "$currentVersion". '
      'Switch to "$requestedVersion"?',
    );
  }

  /// Prompt user to pick a version from list.
  /// Returns null if user cancels or invalid input.
  Future<PhpVersion?> promptVersionPick({
    required List<PhpVersion> availableVersions,
  }) async {
    if (!console.hasTerminal) return null;
    if (availableVersions.isEmpty) return null;

    console.print('Available versions:');
    for (var i = 0; i < availableVersions.length; i++) {
      console.print('  [${i + 1}] ${availableVersions[i]}');
    }
    console.print('  [0] Cancel');

    final input = console.readLine(prompt: 'Choose a version: ');
    if (input == null || input.trim().isEmpty) return null;

    final index = int.tryParse(input.trim());
    if (index == null || index < 0 || index > availableVersions.length) {
      return null;
    }
    if (index == 0) return null;

    return availableVersions[index - 1];
  }
}
