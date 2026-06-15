import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/active_version_resolver.dart';
import '../../core/constants.dart';
import '../../core/os_manager.dart';
import '../../core/platform_constants.dart';
import '../../core/platform_detector.dart';
import '../../core/symlink_inspector.dart';
import '../../domain/exceptions.dart';
import '../../domain/project.dart';
import '../../domain/version_registry.dart';
import '../../version.dart';
import 'diagnostic_check.dart';
import 'diagnostic_models.dart';

/// PVM installation paths and version string.
class PvmInstallationCheck implements DiagnosticCheck {
  final IOSManager _osManager;

  PvmInstallationCheck(this._osManager);

  @override
  String get id => 'pvm-install';

  @override
  String get label => 'PVM Installation';

  @override
  Future<DiagnosticResult> run() async {
    return DiagnosticResult(
      id: id,
      label: label,
      status: DiagnosticStatus.info,
      lines: [
        'programDir : ${_osManager.programDirectory}',
        'version    : $packageVersion',
      ],
    );
  }
}

/// OS / home / global link path (informational).
class PlatformCheck implements DiagnosticCheck {
  final IOSManager _osManager;
  final PlatformConstants _platformConstants;

  PlatformCheck(this._osManager, this._platformConstants);

  @override
  String get id => 'platform';

  @override
  String get label => 'Platform';

  @override
  Future<DiagnosticResult> run() async {
    final home = _osManager.getHomeDirectory();
    final globalLink = p.join(home, PvmConstants.pvmDirName);
    final unknown = PlatformDetector.current == PlatformType.unknown;
    return DiagnosticResult(
      id: id,
      label: label,
      status: unknown ? DiagnosticStatus.warn : DiagnosticStatus.info,
      lines: [
        'os         : ${_platformConstants.osType}',
        'home       : $home',
        'globalLink : $globalLink',
        if (unknown) 'Warning: unsupported or unknown operating system.',
      ],
    );
  }
}

/// Versions directory exists (single source of truth via [IOSManager]).
class VersionsDirectoryCheck implements DiagnosticCheck {
  final IOSManager _osManager;

  VersionsDirectoryCheck(this._osManager);

  @override
  String get id => 'versions-dir';

  @override
  String get label => 'Versions directory';

  @override
  Future<DiagnosticResult> run() async {
    final path = _osManager.phpVersionsPath;
    final exists = await _osManager.directoryExists(path);
    return DiagnosticResult(
      id: id,
      label: label,
      status: exists ? DiagnosticStatus.ok : DiagnosticStatus.warn,
      lines: [
        'path       : $path',
        'exists     : ${exists ? 'yes' : 'no'}',
        if (!exists)
          'Hint: run `pvm install <version>` to create the versions folder.',
      ],
    );
  }
}

/// Installed versions from [VersionRegistry] + php binary sanity.
class InstalledVersionsCheck implements DiagnosticCheck {
  final IOSManager _osManager;
  final PlatformConstants _platformConstants;

  InstalledVersionsCheck(this._osManager, this._platformConstants);

  @override
  String get id => 'installed';

  @override
  String get label => 'Installed versions';

  @override
  Future<DiagnosticResult> run() async {
    final registry = VersionRegistry(_osManager);
    final versions = await registry.getInstalledVersions();
    final versionsPath = _osManager.phpVersionsPath;
    final exists = await _osManager.directoryExists(versionsPath);

    if (!exists) {
      return DiagnosticResult(
        id: id,
        label: label,
        status: DiagnosticStatus.warn,
        lines: [
          'versionsPath missing — cannot list installed versions.',
          'Hint: run `pvm install <version>`.',
        ],
      );
    }

    if (versions.isEmpty) {
      return DiagnosticResult(
        id: id,
        label: label,
        status: DiagnosticStatus.warn,
        lines: [
          'No valid PHP version directories found under:',
          '  $versionsPath',
        ],
      );
    }

    final lines = <String>[];
    var hasBroken = false;
    for (final v in versions) {
      final dir = registry.getVersionPath(v);
      final phpExe = p.join(dir, _platformConstants.phpExecutableName);
      final ok = await _osManager.fileExists(phpExe);
      if (!ok) hasBroken = true;
      lines.add(
        '  - ${v.toString()}${ok ? '' : '  (missing ${p.basename(phpExe)})'}',
      );
    }

    return DiagnosticResult(
      id: id,
      label: label,
      status: hasBroken ? DiagnosticStatus.warn : DiagnosticStatus.ok,
      lines: ['count: ${versions.length}', ...lines],
    );
  }
}

/// Active global / local via [ActiveVersionResolver].
class ActiveVersionsCheck implements DiagnosticCheck {
  final ActiveVersionResolver _resolver;

  ActiveVersionsCheck(this._resolver);

  @override
  String get id => 'active';

  @override
  String get label => 'Active versions';

  @override
  Future<DiagnosticResult> run() async {
    final active = await _resolver.resolve();
    final lines = <String>[
      'global  : ${_formatSlot(active.global)}',
      'local   : ${_formatSlot(active.local)}',
      'effective: ${active.isNone ? 'none' : '${active.version} (${active.scope.name})'}',
    ];
    final anyBroken =
        active.global.status == SymLinkStatus.broken ||
        active.local.status == SymLinkStatus.broken;
    return DiagnosticResult(
      id: id,
      label: label,
      status: anyBroken ? DiagnosticStatus.warn : DiagnosticStatus.ok,
      lines: lines,
    );
  }

  String _formatSlot(SymLinkInfo info) {
    switch (info.status) {
      case SymLinkStatus.notSet:
        return 'not set';
      case SymLinkStatus.ok:
        return '${info.version} -> ${info.target}';
      case SymLinkStatus.broken:
        return 'BROKEN -> ${info.target ?? '(unknown)'}';
      case SymLinkStatus.orphaned:
        return 'ORPHANED -> ${info.target}';
      case SymLinkStatus.corrupt:
        return 'CORRUPT at ${info.linkPath}';
    }
  }
}

/// Live symlink creation probe in a temp directory (skipped when disabled).
class SymlinkProbeCheck implements DiagnosticCheck {
  final IOSManager _osManager;
  final bool enabled;

  SymlinkProbeCheck(this._osManager, {required this.enabled});

  @override
  String get id => 'symlink-probe';

  @override
  String get label => 'Symlink creation probe';

  @override
  Future<DiagnosticResult> run() async {
    if (!enabled) {
      return const DiagnosticResult(
        id: 'symlink-probe',
        label: 'Symlink creation probe',
        status: DiagnosticStatus.info,
        lines: ['Skipped (--no-symlink-test).'],
      );
    }

    Directory? temp;
    try {
      temp = await Directory.systemTemp.createTemp('pvm_doctor_');
      final src = Directory(p.join(temp.path, 'src'));
      await src.create();
      final linkPath = p.join(temp.path, 'probe_link');
      await _osManager.createSymLink('doctor-probe', src.path, linkPath);
      await _osManager.deleteSymLink(linkPath);
      return DiagnosticResult(
        id: id,
        label: label,
        status: DiagnosticStatus.ok,
        lines: ['Created and removed a test symlink under:', '  ${temp.path}'],
      );
    } on Exception catch (e) {
      final hint = PlatformDetector.isWindows
          ? 'Enable Developer Mode (Settings -> Privacy & security -> '
                'For developers) or run pvm as Administrator.'
          : 'Filesystem may not allow symlinks (e.g. FAT/exFAT). '
                'Try a different temp directory.';
      return DiagnosticResult(
        id: id,
        label: label,
        status: DiagnosticStatus.fail,
        lines: [
          'Could not create a test symlink.',
          'reason: $e',
          'hint   : $hint',
        ],
      );
    } finally {
      if (temp != null && await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  }
}

/// Verify the home directory is writable (needed for `pvm global`).
class HomeWritableCheck implements DiagnosticCheck {
  final IOSManager _osManager;

  HomeWritableCheck(this._osManager);

  @override
  String get id => 'home-writable';

  @override
  String get label => 'Home directory writable';

  @override
  Future<DiagnosticResult> run() async {
    final home = _osManager.getHomeDirectory();
    final probeName = 'pvm-doctor-${DateTime.now().microsecondsSinceEpoch}.tmp';
    final probePath = p.join(home, probeName);
    try {
      await File(probePath).writeAsString('pvm-doctor-probe');
      await File(probePath).delete();
      return DiagnosticResult(
        id: id,
        label: label,
        status: DiagnosticStatus.ok,
        lines: ['wrote: $probePath'],
      );
    } catch (e) {
      return DiagnosticResult(
        id: id,
        label: label,
        status: DiagnosticStatus.fail,
        lines: [
          'Could not write a probe file under the home directory.',
          'reason: $e',
          'hint   : `pvm global` will fail until this is fixed.',
        ],
      );
    }
  }
}

/// Whether `%USERPROFILE%\\.pvm` (or equivalent) appears on PATH.
class PathContainsGlobalCheck implements DiagnosticCheck {
  final IOSManager _osManager;
  final PlatformConstants _platformConstants;

  PathContainsGlobalCheck(this._osManager, this._platformConstants);

  @override
  String get id => 'path-global';

  @override
  String get label => 'PATH contains global symlink';

  @override
  Future<DiagnosticResult> run() async {
    final home = _osManager.getHomeDirectory();
    final globalDir = p.join(home, PvmConstants.pvmDirName);
    final pathEnv = _osManager.currentEnvironment['PATH'] ?? '';
    final sep = _platformConstants.pathSeparator;
    final entries = pathEnv
        .split(sep)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    var found = false;
    for (final entry in entries) {
      final cleaned = entry.replaceAll('"', '');
      if (p.equals(p.normalize(cleaned), p.normalize(globalDir))) {
        found = true;
        break;
      }
    }

    return DiagnosticResult(
      id: id,
      label: label,
      status: found ? DiagnosticStatus.ok : DiagnosticStatus.warn,
      lines: [
        if (found)
          'found: $globalDir'
        else ...[
          'The global symlink directory is not on PATH.',
          'expected: $globalDir',
          'hint    : Add it to PATH so the global PHP is discoverable.',
        ],
      ],
    );
  }
}

/// `.pvmrc` in the current project (informational).
class ProjectPvmrcCheck implements DiagnosticCheck {
  final IOSManager _osManager;

  ProjectPvmrcCheck(this._osManager);

  @override
  String get id => 'project-pvmrc';

  @override
  String get label => 'Project';

  @override
  Future<DiagnosticResult> run() async {
    final project = await Project.findFromPath(_osManager.currentDirectory);
    final file = project.pvmrcFile;
    final exists = await file.exists();
    if (!exists) {
      return DiagnosticResult(
        id: id,
        label: label,
        status: DiagnosticStatus.info,
        lines: [
          'root         : ${project.rootDirectory.path}',
          '.pvmrc     : (not found)',
        ],
      );
    }

    try {
      final configured = await project.getConfiguredVersion();
      final registry = VersionRegistry(_osManager);
      final installed = configured == null
          ? false
          : await registry.isInstalled(configured);
      return DiagnosticResult(
        id: id,
        label: label,
        status: DiagnosticStatus.info,
        lines: [
          'root         : ${project.rootDirectory.path}',
          '.pvmrc     : ${configured ?? '(empty)'}',
          if (configured != null) 'installed    : ${installed ? 'yes' : 'no'}',
        ],
      );
    } on InvalidVersionFormatException catch (e) {
      return DiagnosticResult(
        id: id,
        label: label,
        status: DiagnosticStatus.warn,
        lines: [
          'root         : ${project.rootDirectory.path}',
          '.pvmrc     : invalid format',
          'reason       : ${e.message}',
        ],
      );
    }
  }
}
