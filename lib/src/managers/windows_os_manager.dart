import 'dart:io';

import 'package:path/path.dart' as p;
import '../core/constants.dart';
import '../core/os_manager.dart';
import '../core/link_slot.dart';
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

  /// Creates directory links as **junctions** first: they need neither
  /// Developer Mode nor Administrator rights. A symbolic link is only used
  /// when a junction is impossible (e.g. the target is on a network share).
  final Future<void> Function(String link, String target) _createJunction;

  WindowsOSManager({
    Future<void> Function(String link, String target)? createJunction,
  }) : _createJunction = createJunction ?? createJunctionWithPowerShell;

  @override
  Future<({String from, String to})> createSymLink(
    String version,
    String from,
    String to,
  ) async {
    final linkParent = Directory(to).parent;

    if (linkParent.path.isEmpty || !(await directoryExists(linkParent.path))) {
      throw Exception(
        'Error: Link directory does not exist: ${linkParent.path}',
      );
    }
    if (from.isEmpty || !(await directoryExists(from))) {
      throw Exception('Source directory does not exist: $from');
    }

    // Only ever replaces an existing link; a real file/dir aborts (S2).
    await clearLinkSlot(to);

    Object? junctionError;
    try {
      await _createJunction(to, p.absolute(from));
      if (await FileSystemEntity.isLink(to)) return (from: from, to: to);
      junctionError = 'junction was not created';
    } catch (e) {
      junctionError = e;
    }

    try {
      await Link(to).create(from);
      return (from: from, to: to);
    } on FileSystemException catch (e) {
      throw Exception(
        'Error creating link: ${e.message} '
        '(junction attempt: $junctionError)',
      );
    }
  }

  /// Paths are passed via environment variables, never interpolated into the
  /// command, so quotes, `&`, `%VAR%` etc. in paths cannot inject anything.
  static Future<void> createJunctionWithPowerShell(
    String link,
    String target,
  ) async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'New-Item -ItemType Junction -Path $env:PVM_LINK -Target $env:PVM_TARGET | Out-Null',
      ],
      environment: {'PVM_LINK': link, 'PVM_TARGET': target},
    );
    if (result.exitCode != 0) {
      throw Exception('${result.stderr}'.trim());
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
