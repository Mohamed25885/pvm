import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/link_manager.dart';
import '../core/link_slot.dart';
import '../core/os_manager.dart';
import '../core/platform_info.dart';
import '../core/pvm_paths.dart';

/// The one [IOSManager] for every OS. Platform differences come in through
/// [PlatformInfo] (home variable) and [ILinkManager] (how links are made).
class IoOSManager implements IOSManager {
  final PlatformInfo _platform;
  final ILinkManager _links;
  final Map<String, String>? _environment;

  IoOSManager({
    required PlatformInfo platformInfo,
    required ILinkManager linkManager,
    this._environment,
  }) : _platform = platformInfo,
       _links = linkManager;

  /// The directory of the running `pvm` binary (or of `pvm.dart` under
  /// `dart run`), used when `PVM_HOME` is not set.
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
  String get localPath => p.join(currentDirectory, PvmConstants.pvmDirName);

  @override
  String get currentDirectory => Directory.current.path;

  @override
  Map<String, String> get currentEnvironment =>
      _environment ?? Platform.environment;

  @override
  String getHomeDirectory() {
    final env = currentEnvironment;
    for (final key in {_platform.homeDirectoryKey, 'HOME', 'USERPROFILE'}) {
      final value = env[key];
      if (value != null && value.trim().isNotEmpty) return value;
    }
    throw Exception('Could not determine home directory');
  }

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
    await _links.createDirLink(to, from);
    return (from: from, to: to);
  }

  @override
  Future<bool> directoryExists(String path) => Directory(path).exists();

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  /// Bare directory names under [versionsPath]; callers parse and filter
  /// them (see `VersionRegistry`).
  @override
  List<String> getAvailableVersions(String versionsPath) {
    final dir = Directory(versionsPath);
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList();
  }

  @override
  Future<bool> isSymLink(String path) => _links.isLink(path);

  @override
  Future<String?> readSymLinkTarget(String path) => _links.readTarget(path);

  @override
  Future<void> deleteSymLink(String path) => _links.remove(path);

  @override
  Future<void> deleteDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;
    await dir.delete(recursive: true);
  }
}
