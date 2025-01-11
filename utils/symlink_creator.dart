import 'dart:io';

class SymlinkCreator {
  static Future<({String from, String to})> createSymLink(String version, String from, String to) async {
    final linkPath = to;
    final targetPath = from;

    final homeDir = Directory(linkPath).parent;

    if (homeDir.path.isEmpty || !(await homeDir.exists())) {
      throw Exception('Error: Could not determine home directory.');
    }
    if (targetPath.isEmpty || !(await Directory(targetPath).exists())) {
      throw Exception('Error: Could not determine home directory.');
    }

    try {
      Process.runSync('cmd', [
        '/c'
            'rmdir',
        linkPath,
      ]);
    } catch (e) {}

    // Check the operating system
    // Windows: Use `mklink` command
    final result = await Process.run('cmd', [
      '/c',
      'mklink',
      '/D',
      linkPath,
      targetPath,
    ]);

    if (result.exitCode == 0) {
      return (from: targetPath, to: linkPath);
    }

    throw Exception('Error creating symbolic link: ${result.stderr}');
  }
}
