import 'dart:io';

/// Manages .gitignore entries at the project root.
/// Best-effort: failures are non-fatal.
class GitIgnoreService {
  /// Ensure .gitignore exists at [rootPath] and contains an entry
  /// that ignores .pvm (both as a file/dir and as a symlink).
  /// Idempotent — safe to call multiple times.
  /// Returns true if .gitignore was modified, false if it already had .pvm.
  Future<bool> ensureGitignoreIncludesPvm({required String rootPath}) async {
    final gitignore = File('$rootPath\\.gitignore');

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
      return t == '.pvm' || t == '/.pvm';
    });

    if (!alreadyIgnored) {
      final entry = existing.isNotEmpty && !existing.endsWith('\n')
          ? '\n/.pvm\n'
          : '/.pvm\n';
      await gitignore.writeAsString(existing + entry);
      return true;
    }
    return false;
  }

  /// Attempt to create a .pvm symlink at [symlinkPath] pointing to
  /// [targetPath]. Best-effort — returns true if the symlink was created
  /// (or already exists as a symlink), false if it failed.
  ///
  /// If .pvm already exists (as a file, dir, or symlink), returns true
  /// without modifying anything.
  ///
  /// Returns false if [targetPath] does not exist.
  Future<bool> ensurePvmSymlinkExists({
    required String symlinkPath,
    required String targetPath,
  }) async {
    try {
      // Validate target exists before attempting symlink creation
      if (!Directory(targetPath).existsSync()) {
        return false;
      }

      final link = Link(symlinkPath);

      // Already exists as a symlink — nothing to do
      if (await link.exists()) return true;

      // If a regular file/directory exists at symlinkPath, remove it first
      if (await File(symlinkPath).exists() ||
          await Directory(symlinkPath).exists()) {
        await File(symlinkPath).delete(recursive: true);
      }

      await link.create(targetPath);
      return true;
    } catch (e) {
      // Best-effort — symlink creation can fail due to permissions,
      // Developer Mode not enabled on Windows, or OS restrictions.
      return false;
    }
  }
}
