import 'dart:convert';
import 'dart:io';

/// Reads and writes .php-version at the project root.
/// Supports plain version string (legacy) or JSON for future extensions.
class PhpVersionManager {
  /// Read the last used version from .php-version at [rootPath].
  /// Returns null if the file doesn't exist or is empty.
  /// Supports plain version string ("8.2") or JSON object.
  Future<String?> readLastUsedVersion({required String rootPath}) async {
    final file = File('$rootPath\\.php-version');
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      // Try JSON first
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      return json['version'] as String?;
    } catch (_) {
      // Plain version string
      return trimmed;
    }
  }

  /// Write [version] to .php-version at [rootPath] as JSON.
  Future<void> writeCurrentVersion({
    required String rootPath,
    required String version,
  }) async {
    final file = File('$rootPath\\.php-version');
    final data = {'version': version};
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  /// Prompt the user when a version mismatch is detected.
  /// Default Yes — user presses Enter or types Y.
  /// Returns true if the user confirms, false otherwise.
  Future<bool> promptMismatch({
    required String currentVersion,
    required String requestedVersion,
  }) async {
    if (!stdout.hasTerminal) return false;
    stdout.write('Detected .php-version contains "$currentVersion". '
        'Switch to "$requestedVersion"? (Y/n): ');
    final line = stdin.readLineSync();
    if (line == null) return false;
    final trimmed = line.trim().toLowerCase();
    // Default Yes — empty input or y/Y means confirm
    return trimmed.isEmpty || trimmed == 'y';
  }

  /// Prompt the user to pick a version from [availableVersions].
  /// Used when .php-version contains a version that's not installed.
  /// Returns the chosen version, or null if the user cancelled.
  Future<String?> promptVersionPick({
    required List<String> availableVersions,
  }) async {
    if (!stdout.hasTerminal) return null;
    if (availableVersions.isEmpty) return null;
    print('Available versions:');
    for (var i = 0; i < availableVersions.length; i++) {
      print('  [${i + 1}] ${availableVersions[i]}');
    }
    print('  [0] Cancel');
    stdout.write('Choose a version: ');
    final line = stdin.readLineSync();
    if (line == null) return null;
    final trimmed = line.trim();
    final index = int.tryParse(trimmed);
    if (index == null || index < 0 || index > availableVersions.length) {
      return null;
    }
    if (index == 0) return null;
    return availableVersions[index - 1];
  }
}
