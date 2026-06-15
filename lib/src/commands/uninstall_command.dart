import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../core/symlink_inspector.dart';
import '../domain/exceptions.dart';
import '../domain/installed_version_resolver.dart';
import '../domain/php_version.dart';
import '../domain/project.dart';
import '../domain/version_diagnostics.dart';
import '../domain/version_registry.dart';

/// `pvm uninstall <version>` — remove an installed PHP version directory.
class UninstallCommand extends Command<int> {
  @override
  final String name = 'uninstall';

  @override
  final String description =
      'Uninstall a PHP version from the local versions directory';

  @override
  final ArgParser argParser = ArgParser()
    ..addFlag(
      'force',
      help: 'Allow uninstalling the active global version (implies --yes).',
      negatable: false,
    )
    ..addFlag(
      'yes',
      abbr: 'y',
      help: 'Skip the confirmation prompt (does not bypass --force guard).',
      negatable: false,
    )
    ..addFlag(
      'keep-symlinks',
      help: 'Do not remove dangling global/local symlinks.',
      negatable: false,
    );

  final IOSManager _osManager;
  final SymLinkInspector _inspector;
  final Console _console;

  UninstallCommand({
    required IOSManager osManager,
    required SymLinkInspector symlinkInspector,
    required Console console,
  }) : _osManager = osManager,
       _inspector = symlinkInspector,
       _console = console;

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      _console.printError('No version specified.');
      _console.print('Usage: pvm uninstall <version>');
      return ExitCode.usageError;
    }
    if (argResults!.rest.length > 1) {
      _console.printError('Too many arguments. Usage: pvm uninstall <version>');
      return ExitCode.usageError;
    }

    final rawVersion = argResults!.rest.first;
    late final PhpVersion parsed;
    try {
      parsed = PhpVersion.parse(rawVersion);
    } on InvalidVersionFormatException catch (e) {
      _console.printError(e.message);
      return ExitCode.usageError;
    }

    final registry = VersionRegistry(_osManager);
    final installed = await registry.getInstalledVersions();
    final PhpVersion resolved;
    switch (InstalledVersionResolver.resolve(parsed, installed)) {
      case ResolvedInstalledVersion(:final version):
        resolved = version;
      case AmbiguousInstalledVersion(:final candidates):
        _console.printError(
          VersionDiagnostics.ambiguousVersionMessage(
            requested: parsed,
            matches: candidates,
          ),
        );
        return ExitCode.versionNotFound;
      case NotFoundInstalledVersion():
        _console.printError(
          VersionDiagnostics.notInstalledMessage(
            requested: parsed,
            installed: installed,
          ),
        );
        return ExitCode.versionNotFound;
    }

    final versionDir = registry.getVersionPath(resolved);
    if (!await _osManager.directoryExists(versionDir)) {
      _console.printError(
        VersionDiagnostics.notInstalledMessage(
          requested: resolved,
          installed: installed,
        ),
      );
      return ExitCode.versionNotFound;
    }

    final force = argResults!['force'] as bool;
    final yes = argResults!['yes'] as bool || force;
    final keepSymlinks = argResults!['keep-symlinks'] as bool;

    final globalInfo = await _inspector.inspectGlobal();
    if (!force &&
        globalInfo.status == SymLinkStatus.ok &&
        globalInfo.target != null &&
        p.equals(p.normalize(globalInfo.target!), p.normalize(versionDir))) {
      _console.printError(
        'Cannot uninstall $resolved: it is the currently active global version.\n'
        'Switch to another version first (`pvm global <other>`) or pass --force.',
      );
      return ExitCode.generalError;
    }

    final project = await Project.findFromPath(_osManager.currentDirectory);
    final localInfo = await _inspector.inspectLocal(project.rootDirectory.path);
    if (localInfo.status == SymLinkStatus.ok &&
        localInfo.target != null &&
        p.equals(p.normalize(localInfo.target!), p.normalize(versionDir))) {
      _console.printWarning(
        'This project\'s local `.pvm` symlink points at $resolved.',
      );
    }

    if (force &&
        globalInfo.status == SymLinkStatus.ok &&
        globalInfo.target != null &&
        p.equals(p.normalize(globalInfo.target!), p.normalize(versionDir))) {
      _console.printWarning(
        '$resolved is the currently active global version. Forcing uninstall.',
      );
    }

    if (!yes) {
      final confirmed = await _console.confirm(
        'Delete PHP $resolved at $versionDir? This cannot be undone.',
      );
      if (!confirmed) {
        _console.print('Cancelled.');
        return ExitCode.userCancelled;
      }
    }

    if (!keepSymlinks) {
      await _cleanupSymlinkIfPointsTo(versionDir, globalInfo);
      await _cleanupSymlinkIfPointsTo(versionDir, localInfo);
    }

    try {
      await _osManager.deleteDirectory(versionDir);
    } on FileSystemException catch (e) {
      _console.printError(
        'Could not delete directory: ${e.message}\n'
        'hint: close any running PHP processes using files under:\n'
        '  $versionDir',
      );
      return ExitCode.permissionDenied;
    } catch (e) {
      _console.printError('Could not delete directory: $e');
      return ExitCode.generalError;
    }

    PhpVersion? configured;
    try {
      configured = await project.getConfiguredVersion();
    } on InvalidVersionFormatException {
      configured = null;
    }
    if (configured != null && configured == resolved) {
      _console.printWarning(
        '.pvmrc still declares $resolved. Run `pvm use <other>` to switch.',
      );
    }

    _console.print('Removed $versionDir');
    return ExitCode.success;
  }

  Future<void> _cleanupSymlinkIfPointsTo(
    String versionDir,
    SymLinkInfo info,
  ) async {
    if (info.status != SymLinkStatus.ok || info.target == null) return;
    if (!p.equals(p.normalize(info.target!), p.normalize(versionDir))) return;
    try {
      await _osManager.deleteSymLink(info.linkPath);
      _console.print('Removed dangling symlink at ${info.linkPath}');
    } catch (e) {
      _console.printWarning('Could not remove symlink ${info.linkPath}: $e');
    }
  }
}
