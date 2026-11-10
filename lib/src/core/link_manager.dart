import 'dart:io';

import 'package:path/path.dart' as p;

import 'platform_info.dart';

/// Creates and inspects the directory links PVM uses (`.pvm` →
/// `versions/<v>`). This is the only place that knows how a link is made on
/// each OS.
abstract interface class ILinkManager {
  /// Create a directory link at [link] pointing to [target].
  ///
  /// The caller makes sure the slot at [link] is empty first.
  Future<void> createDirLink(String link, String target);

  /// Whether [path] is a link (symlink or junction), without following it.
  /// `false` when nothing is there.
  Future<bool> isLink(String path);

  /// The raw stored target of the link at [path], or `null` when [path] is
  /// not a link or cannot be read.
  Future<String?> readTarget(String path);

  /// Remove the link at [path] (never its target). No-op when nothing is
  /// there; throws [FileSystemException] when [path] is not a link.
  Future<void> remove(String path);
}

/// Plain symbolic links: the link model on Linux and macOS.
class SymlinkLinkManager implements ILinkManager {
  const SymlinkLinkManager();

  @override
  Future<void> createDirLink(String link, String target) async {
    try {
      await Link(link).create(target);
    } on FileSystemException catch (e) {
      throw Exception('Error creating link: ${e.message}');
    }
  }

  @override
  Future<bool> isLink(String path) async =>
      await FileSystemEntity.type(path, followLinks: false) ==
      FileSystemEntityType.link;

  @override
  Future<String?> readTarget(String path) async {
    if (!await isLink(path)) return null;
    try {
      return await Link(path).target();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> remove(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.link) {
      throw FileSystemException('Path is not a symbolic link', path);
    }
    await Link(path).delete();
  }
}

/// Windows: **junctions** first, since they need neither Developer Mode nor
/// Administrator rights. A symbolic link is only used when a junction is
/// impossible (e.g. the target is on a network share).
///
/// Dart reports junctions as links, so inspection and removal are shared
/// with [SymlinkLinkManager].
class JunctionLinkManager extends SymlinkLinkManager {
  final Future<void> Function(String link, String target) _createJunction;

  const JunctionLinkManager({
    Future<void> Function(String link, String target)? createJunction,
  }) : _createJunction = createJunction ?? createJunctionWithPowerShell;

  @override
  Future<void> createDirLink(String link, String target) async {
    Object? junctionError;
    try {
      await _createJunction(link, p.absolute(target));
      if (await isLink(link)) return;
      junctionError = 'junction was not created';
    } catch (e) {
      junctionError = e;
    }

    try {
      await Link(link).create(target);
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
}

/// The link model for [platform].
ILinkManager createLinkManager(PlatformInfo platform) =>
    platform.osType == 'windows'
    ? const JunctionLinkManager()
    : const SymlinkLinkManager();
