import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../domain/php_version.dart';
import '../domain/exceptions.dart';
import 'console.dart';
import 'constants.dart';

class PhpVersionManager {
  final Console console;

  PhpVersionManager(this.console);

  /// Read version from .php-version file.
  /// Returns null if file doesn't exist or is empty.
  /// Throws [ProjectConfigurationException] on invalid format.
  Future<PhpVersion?> readLastUsedVersion({required String rootPath}) async {
    final file = File(p.join(rootPath, PvmConstants.phpVersionFileName));
    if (!await file.exists()) return null;

    final raw = await file.readAsString();
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      // Try JSON first
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      final versionStr = json['version'] as String?;
      if (versionStr != null) {
        return PhpVersion.parse(versionStr);
      }
    } catch (_) {
      // Not JSON, try plain text
    }

    return PhpVersion.parse(trimmed);
  }

  /// Write version to .php-version file in JSON format.
  Future<void> writeCurrentVersion({
    required String rootPath,
    required PhpVersion version,
  }) async {
    final file = File(p.join(rootPath, PvmConstants.phpVersionFileName));
    final data = {'version': version.toString()};
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  /// Prompt user to switch versions (returns true if user confirms).
  /// Default: NO (safe default - user must explicitly type 'y').
  Future<bool> promptMismatch({
    required PhpVersion currentVersion,
    required PhpVersion requestedVersion,
  }) async {
    if (!console.hasTerminal) return false;

    final input = console.readLine(
      prompt: 'Detected .php-version contains "$currentVersion". '
          'Switch to "$requestedVersion"? (y/N): ',
    );

    if (input == null) return false;
    final trimmed = input.trim().toLowerCase();
    return trimmed == 'y';
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
