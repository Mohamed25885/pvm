import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/console.dart';
import '../core/constants.dart';
import '../core/exit_codes.dart';
import '../core/gitignore_service.dart';
import '../core/os_manager.dart';
import '../core/php_version_manager.dart';
import '../domain/exceptions.dart';
import '../domain/installed_version_resolver.dart';
import '../domain/php_version.dart';
import '../domain/project.dart';
import '../domain/version_diagnostics.dart';
import '../domain/version_registry.dart';
import '../interfaces/i_version_activator.dart';
import '../core/error_text.dart';

class UseCommand extends Command<int> {
  @override
  final String name = 'use';

  @override
  final String description =
      'Set the local PHP version (project-specific). '
      'Without a version argument, uses the version from .pvmrc if present.';

  final IOSManager _osManager;
  final PhpVersionManager _phpVersionManager;
  final GitIgnoreService _gitIgnoreService;
  final IVersionActivator _versionActivator;
  final Console _console;

  UseCommand(
    this._osManager,
    this._phpVersionManager,
    this._gitIgnoreService,
    this._versionActivator,
    this._console,
  );

  /// A project root must never be the home directory (its `.pvm` is the
  /// global slot) or a filesystem root (S3).
  String? _unsafeRootReason(String root) {
    final normalized = p.normalize(root);
    if (p.equals(p.dirname(normalized), normalized)) {
      return 'a filesystem root';
    }
    try {
      if (p.equals(normalized, p.normalize(_osManager.getHomeDirectory()))) {
        return 'your home directory (its .pvm is the global version link)';
      }
    } catch (_) {
      // Home unknown: nothing to protect against.
    }
    return null;
  }

  @override
  Future<int> run() async {
    try {
      final project = await Project.locate(_osManager);
      final registry = VersionRegistry(_osManager);

      final unsafe = _unsafeRootReason(project.rootDirectory.path);
      if (unsafe != null) {
        _console.printError(
          'Refusing to set a local version in $unsafe: '
          '${project.rootDirectory.path}',
        );
        _console.print(
          'Run this inside a project folder, or create a .pvmrc there first. '
          'Use "pvm global <version>" for a machine-wide default.',
        );
        return ExitCode.configurationError;
      }

      final requestedVersionStr = argResults?.rest.firstOrNull;

      if (requestedVersionStr == null) {
        return await _useConfiguredVersion(project, registry);
      }

      if (argResults!.rest.length > 1) {
        _console.printError('Too many arguments. Usage: pvm use <version>');
        return ExitCode.usageError;
      }

      final requestedVersion = PhpVersion.parse(requestedVersionStr);
      return await _useSpecificVersion(project, requestedVersion, registry);
    } on InvalidVersionFormatException catch (e) {
      _console.printError(e.message);
      return ExitCode.usageError;
    } on ProjectConfigurationException catch (e) {
      _console.printError(e.message);
      return ExitCode.configurationError;
    } on PvmException catch (e) {
      _console.printError(e.message);
      return ExitCode.generalError;
    }
  }

  Future<int> _useConfiguredVersion(
    Project project,
    VersionRegistry registry,
  ) async {
    final configured = await _phpVersionManager.readLastUsedVersion(
      rootPath: project.rootDirectory.path,
    );

    if (configured == null) {
      _console.printError('No version specified and no .pvmrc file found.');
      _console.print('Usage: pvm use <version>');
      return ExitCode.usageError;
    }

    return _useSpecificVersion(project, configured, registry, updateFile: true);
  }

  Future<int> _useSpecificVersion(
    Project project,
    PhpVersion requestedVersion,
    VersionRegistry registry, {
    bool updateFile = true,
  }) async {
    // Skip folders that are not versions (e.g. versions/tmp) (B3).
    final available = VersionRegistry.parseVersionNames(
      _osManager.getAvailableVersions(_osManager.phpVersionsPath),
    );
    final resolveResult = InstalledVersionResolver.resolve(
      requestedVersion,
      available,
    );
    final PhpVersion resolvedVersion;
    switch (resolveResult) {
      case ResolvedInstalledVersion(:final version):
        resolvedVersion = version;
      case AmbiguousInstalledVersion(:final candidates):
        _console.printError(
          VersionDiagnostics.ambiguousVersionMessage(
            requested: requestedVersion,
            matches: candidates,
          ),
        );
        return ExitCode.versionNotFound;
      case NotFoundInstalledVersion():
        if (_console.hasTerminal) {
          final picked = await _phpVersionManager.promptVersionPick(
            availableVersions: available,
          );
          if (picked == null) {
            _console.print('Cancelled.');
            return ExitCode.userCancelled;
          }
          return _useSpecificVersion(
            project,
            picked,
            registry,
            updateFile: updateFile,
          );
        }
        _console.printError(
          VersionDiagnostics.notInstalledMessage(
            requested: requestedVersion,
            installed: available,
          ),
        );
        return ExitCode.versionNotFound;
    }
    requestedVersion = resolvedVersion;

    // Sanity check: directory exists
    final sourcePath = registry.getVersionPath(requestedVersion);
    if (!await _osManager.directoryExists(sourcePath)) {
      _console.printError('Version directory not found at $sourcePath');
      return ExitCode.versionNotFound;
    }

    // Check for mismatch
    final configured = await project.getConfiguredVersion();
    if (configured != null && configured != requestedVersion) {
      if (_console.hasTerminal) {
        final confirmed = await _phpVersionManager.promptMismatch(
          currentVersion: configured,
          requestedVersion: requestedVersion,
        );
        if (!confirmed) {
          _console.print('Cancelled.');
          return ExitCode.userCancelled;
        }
        // User confirmed, apply with updateFile: true
        return _applyVersion(
          project,
          requestedVersion,
          registry,
          updateFile: true,
        );
      } else {
        // Non-interactive: apply but don't update file
        return _applyVersion(
          project,
          requestedVersion,
          registry,
          updateFile: false,
        );
      }
    }

    // No mismatch or same version: apply with caller's updateFile preference
    return _applyVersion(
      project,
      requestedVersion,
      registry,
      updateFile: updateFile,
    );
  }

  Future<int> _applyVersion(
    Project project,
    PhpVersion version,
    VersionRegistry registry, {
    required bool updateFile,
  }) async {
    final localPath = p.join(
      project.rootDirectory.path,
      PvmConstants.pvmDirName,
    );
    final sourcePath = registry.getVersionPath(version);

    try {
      if (!await _osManager.directoryExists(sourcePath)) {
        _console.printError('Version directory not found at $sourcePath');
        return ExitCode.versionNotFound;
      }

      // Use the activator to create the local symlink
      await _versionActivator.activateLocal(version.slot);

      if (updateFile) {
        await _phpVersionManager.writeCurrentVersion(
          rootPath: project.rootDirectory.path,
          version: version,
        );
      }

      // Only touch .gitignore once the link exists (B4). Best-effort.
      try {
        await _gitIgnoreService.ensureGitignoreIncludesPvm(
          rootPath: project.rootDirectory.path,
        );
      } catch (e) {
        _console.printWarning(
          'Could not update .gitignore: ${describeError(e)}',
        );
      }

      _console.print('Local link created: $localPath -> $sourcePath');
      return ExitCode.success;
    } catch (e) {
      _console.printError('Error: ${describeError(e)}');
      return ExitCode.generalError;
    }
  }
}
