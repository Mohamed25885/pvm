import 'dart:io';

import '../core/os_manager.dart';

class WindowsOSManager implements IOSManager {
  @override
  String get programDirectory => File(Platform.script.toFilePath()).parent.path;

  @override
  String get phpVersionsPath => "$programDirectory\\versions";

  @override
  String get localPath => "${Directory.current.path}\\.pvm";

  @override
  String get currentDirectory => Directory.current.path;

  String get directoryName => '.pvm';

  @override
  String getHomeDirectory() {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw Exception('Could not determine home directory');
    }
    return home;
  }

  @override
  Future<({String from, String to})> createSymLink(
      String version, String from, String to) async {
    final homeDir = Directory(to).parent;

    if (homeDir.path.isEmpty || !(await directoryExists(homeDir.path))) {
      throw Exception('Error: Could not determine home directory.');
    }
    if (from.isEmpty || !(await directoryExists(from))) {
      throw Exception('Error: Source directory does not exist: $from');
    }

    try {
      Process.runSync('cmd', ['/c', 'rmdir', to]);
    } catch (_) {}

    final result = await Process.run('cmd', [
      '/c',
      'mklink',
      '/D',
      to,
      from,
    ]);

    if (result.exitCode == 0) {
      return (from: from, to: to);
    }

    throw Exception('Error creating symbolic link: ${result.stderr}');
  }

  @override
  Future<bool> directoryExists(String path) async {
    return await Directory(path).exists();
  }

  @override
  Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  @override
  List<String> getAvailableVersions(String versionsPath) {
    if (!Directory(versionsPath).existsSync()) {
      return [];
    }
    return Directory(versionsPath)
        .listSync()
        .where((FileSystemEntity entity) => entity is Directory)
        .map((FileSystemEntity entity) =>
            entity.path.split(Platform.pathSeparator).last)
        .toList();
  }
}
