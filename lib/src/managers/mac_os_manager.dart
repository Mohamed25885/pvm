import 'dart:io';
import 'package:path/path.dart' as p;

import '../core/os_manager.dart';

/// macOS OS Manager - implements all IOSManager operations for macOS.
class MacOSManager implements IOSManager {
  @override
  String get programDirectory => p.join(homeDirectory, '.pvm');

  @override
  String get phpVersionsPath => p.join(homeDirectory, '.pvm', 'versions');

  @override
  String get localPath => p.join(Directory.current.path, '.pvm');

  @override
  String get currentDirectory => Directory.current.path;

  @override
  String getHomeDirectory() {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/Users/${Platform.environment['USER']}';
  }

  @override
  Map<String, String> get currentEnvironment => Platform.environment;

  @override
  Future<({String from, String to})> createSymLink(
      String version, String from, String to) async {
    // Use ln -s for macOS
    final result = await Process.run('ln', ['-sf', to, from]);

    if (result.exitCode != 0) {
      throw Exception('Failed to create symlink: ${result.stderr}');
    }

    return (from: from, to: to);
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
