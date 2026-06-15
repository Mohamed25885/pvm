import 'dart:io';

import 'package:path/path.dart' as p;
import '../core/constants.dart';
import '../core/os_manager.dart';
import '../core/pvm_paths.dart';

class WindowsOSManager implements IOSManager {
  String get _programDirectoryFallback {
    final exePath = Platform.resolvedExecutable;
    if (p.basename(exePath).startsWith('dart')) {
      return File(Platform.script.toFilePath()).parent.path;
    }
    return File(exePath).parent.path;
  }

  PvmPaths get _paths => PvmPaths.fromEnvironment(
    currentEnvironment,
    programDirectoryFallback: _programDirectoryFallback,
  );

  @override
  String get programDirectory => _paths.pvmHome;

  @override
  String get phpVersionsPath => _paths.versionsHome;

  @override
  String get localPath =>
      p.join(Directory.current.path, PvmConstants.pvmDirName);

  @override
  String get currentDirectory => Directory.current.path;

  @override
  Map<String, String> get currentEnvironment => Platform.environment;

  String get directoryName => PvmConstants.pvmDirName;

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
    String version,
    String from,
    String to,
  ) async {
    final homeDir = Directory(to).parent;

    if (homeDir.path.isEmpty || !(await directoryExists(homeDir.path))) {
      throw Exception('Error: Could not determine home directory.');
    }
    if (from.isEmpty || !(await directoryExists(from))) {
      throw Exception('Error: Source directory does not exist: $from');
    }

    try {
      final existingType = await FileSystemEntity.type(to, followLinks: false);
      if (existingType != FileSystemEntityType.notFound) {
        if (existingType == FileSystemEntityType.link) {
          await Link(to).delete();
        } else if (existingType == FileSystemEntityType.directory) {
          await Directory(to).delete(recursive: true);
        } else {
          await File(to).delete();
        }
      }
    } catch (_) {
      // ignore - create will surface meaningful failures
    }

    try {
      await Link(to).create(from);
      return (from: from, to: to);
    } on FileSystemException catch (e) {
      throw Exception('Error creating symbolic link: ${e.message}');
    }
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
        .whereType<Directory>()
        .map((Directory dir) => p.basename(dir.path))
        .toList();
  }

  @override
  Future<bool> isSymLink(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    return type == FileSystemEntityType.link;
  }

  @override
  Future<String?> readSymLinkTarget(String path) async {
    if (!await isSymLink(path)) return null;
    try {
      return await Link(path).target();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> deleteSymLink(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.link) {
      throw FileSystemException('Path is not a symbolic link', path);
    }
    await Link(path).delete();
  }

  @override
  Future<void> deleteDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;
    await dir.delete(recursive: true);
  }
}
