import 'dart:io';
import 'package:path/path.dart' as p;

import 'os_manager.dart';
import 'constants.dart';
import 'console.dart';

/// Manages .gitignore entries at the project root.
/// Best-effort: failures are non-fatal.
class GitIgnoreService {
  final IOSManager _osManager; // ignore: unused_field
  final Console _console; // ignore: unused_field

  GitIgnoreService(this._osManager, this._console);

  /// Ensure .gitignore exists at [rootPath] and contains an entry
  /// that ignores .pvm (both as a file/dir and as a symlink).
  /// Idempotent — safe to call multiple times.
  /// Returns true if .gitignore was modified, false if it already had .pvm.
  Future<bool> ensureGitignoreIncludesPvm({required String rootPath}) async {
    final gitignore = File(p.join(rootPath, PvmConstants.gitignoreFileName));

    String existing = '';
    if (await gitignore.exists()) {
      existing = await gitignore.readAsString();
    }

    // Normalize: split by newline, trim, remove empty lines for comparison
    final lines = existing
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Check if any existing line already covers .pvm ignoring
    final alreadyIgnored = lines.any((l) {
      final t = l.replaceAll(RegExp(r'[#/\\]+$'), ''); // strip trailing / or #
      return t == PvmConstants.pvmDirName || t == '/${PvmConstants.pvmDirName}';
    });

    if (!alreadyIgnored) {
      final entry = existing.isNotEmpty && !existing.endsWith('\n')
          ? '\n/${PvmConstants.pvmDirName}\n'
          : '/${PvmConstants.pvmDirName}\n';
      await gitignore.writeAsString(existing + entry);
      return true;
    }
    return false;
  }
}
