import 'dart:io';
import 'package:path/path.dart' as p;

import '../core/os_manager.dart';

/// Linux OS Manager - implements all IOSManager operations for Linux.
class LinuxOSManager implements IOSManager {
  String get _scriptDirectory => File(Platform.script.toFilePath()).parent.path;

  @override
  String get programDirectory => _scriptDirectory;

  @override
  String get phpVersionsPath {
    final preferred = p.join(programDirectory, 'versions');
    final legacy = p.join(homeDirectory, '.pvm', 'versions');

    if (Directory(preferred).existsSync()) return preferred;
    if (Directory(legacy).existsSync()) return legacy;
    return preferred;
  }

  @override
  String get localPath => p.join(Directory.current.path, '.pvm');

  @override
  String get currentDirectory => Directory.current.path;

  @override
  String getHomeDirectory() {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/home/${Platform.environment['USER']}';
  }

  @override
  Map<String, String> get currentEnvironment => Platform.environment;

  @override
  Future<({String from, String to})> createSymLink(
      String version, String from, String to) async {
    try {
      // Replace existing link/dir if present (best-effort).
      final existingType = await FileSystemEntity.type(to, followLinks: false);
      if (existingType != FileSystemEntityType.notFound) {
        if (existingType == FileSystemEntityType.directory) {
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
      throw Exception('Failed to create symlink: ${e.message}');
    }
  }

  @override
  Future<bool> directoryExists(String path) async {
    return Directory(path).exists();
  }

  @override
  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  @override
  List<String> getAvailableVersions(String versionsPath) {
    final dir = Directory(versionsPath);
    if (!dir.existsSync()) return [];

    return dir
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .where((name) => RegExp(r'^\d+\.\d+').hasMatch(name))
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Sort descending
  }

  /// Helper to get home directory (cached)
  String get homeDirectory => getHomeDirectory();
}
