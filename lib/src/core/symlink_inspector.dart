import 'package:path/path.dart' as p;

import '../domain/exceptions.dart';
import '../domain/php_version.dart';
import 'constants.dart';
import 'os_manager.dart';

/// Status taxonomy for the slot where pvm expects to find a symlink.
enum SymLinkStatus {
  /// The link path does not exist at all.
  notSet,

  /// The link is a real symlink whose target exists and is a valid version
  /// directory inside the pvm versions root.
  ok,

  /// The link exists and is a symlink, but its target does not exist.
  broken,

  /// The link exists and points to a real directory, but the target lives
  /// outside the pvm versions root (i.e. was created by something else).
  orphaned,

  /// The link path exists but is not a symbolic link (e.g. someone created
  /// a regular directory or file at the slot).
  corrupt,
}

/// Snapshot of a single symlink slot ([linkPath]).
///
/// Returned by [SymLinkInspector] for the well-known global and local
/// locations. Consumers (commands, doctor checks) branch on [status] and
/// surface [version] / [target] / [linkPath] in their messages.
class SymLinkInfo {
  final String linkPath;
  final SymLinkStatus status;
  final String? target;
  final PhpVersion? version;

  const SymLinkInfo({
    required this.linkPath,
    required this.status,
    this.target,
    this.version,
  });

  bool get isOk => status == SymLinkStatus.ok;

  @override
  String toString() =>
      'SymLinkInfo(linkPath: $linkPath, status: $status, target: $target, version: $version)';
}

/// Inspects a single symlink slot and classifies it via [SymLinkStatus].
///
/// This is the canonical way to read pvm's symlinks. Every command that
/// needs to know "what version is active here?" must go through this
/// service rather than reading filesystem state directly.
class SymLinkInspector {
  final IOSManager _osManager;

  SymLinkInspector(this._osManager);

  /// Inspect the slot at [linkPath] and classify it.
  ///
  /// [versionsRoot] is the root under which valid version directories live
  /// (e.g. `osManager.phpVersionsPath`). Targets pointing outside this
  /// directory are reported as [SymLinkStatus.orphaned].
  Future<SymLinkInfo> inspect({
    required String linkPath,
    required String versionsRoot,
  }) async {
    if (!await _osManager.isSymLink(linkPath)) {
      // Not a symlink. Either nothing is there, or something else is.
      final fileExists = await _osManager.fileExists(linkPath);
      final dirExists = await _osManager.directoryExists(linkPath);
      if (!fileExists && !dirExists) {
        return SymLinkInfo(
          linkPath: linkPath,
          status: SymLinkStatus.notSet,
        );
      }
      return SymLinkInfo(
        linkPath: linkPath,
        status: SymLinkStatus.corrupt,
      );
    }

    final target = await _osManager.readSymLinkTarget(linkPath);
    if (target == null) {
      return SymLinkInfo(
        linkPath: linkPath,
        status: SymLinkStatus.broken,
      );
    }

    final targetExists = await _osManager.directoryExists(target);
    if (!targetExists) {
      return SymLinkInfo(
        linkPath: linkPath,
        status: SymLinkStatus.broken,
        target: target,
      );
    }

    final inside = _isInside(target, versionsRoot);
    if (!inside) {
      return SymLinkInfo(
        linkPath: linkPath,
        status: SymLinkStatus.orphaned,
        target: target,
      );
    }

    final basename = p.basename(target);
    PhpVersion? version;
    try {
      version = PhpVersion.parse(basename);
    } on InvalidVersionFormatException {
      version = null;
    }

    return SymLinkInfo(
      linkPath: linkPath,
      status: version == null ? SymLinkStatus.orphaned : SymLinkStatus.ok,
      target: target,
      version: version,
    );
  }

  /// Convenience: inspect the global slot at `<homeDir>/.pvm`.
  Future<SymLinkInfo> inspectGlobal() async {
    final linkPath =
        p.join(_osManager.getHomeDirectory(), PvmConstants.pvmDirName);
    return inspect(
      linkPath: linkPath,
      versionsRoot: _osManager.phpVersionsPath,
    );
  }

  /// Convenience: inspect the local slot at `<projectRoot>/.pvm`.
  Future<SymLinkInfo> inspectLocal(String projectRoot) async {
    final linkPath = p.join(projectRoot, PvmConstants.pvmDirName);
    return inspect(
      linkPath: linkPath,
      versionsRoot: _osManager.phpVersionsPath,
    );
  }

  bool _isInside(String target, String root) {
    final normTarget = p.normalize(target);
    final normRoot = p.normalize(root);
    return p.isWithin(normRoot, normTarget) ||
        p.equals(p.dirname(normTarget), normRoot);
  }
}
