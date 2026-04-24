import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/console.dart';
import '../core/constants.dart';
import '../core/exit_codes.dart';
import '../core/gitignore_service.dart';
import '../core/os_manager.dart';
import '../core/php_version_manager.dart';
import '../domain/exceptions.dart';
import '../domain/php_version.dart';
import '../domain/project.dart';
import '../domain/version_registry.dart';
import '../interfaces/i_version_activator.dart';

class UseCommand extends Command<int> {
  @override
  final String name = 'use';

  @override
  final String description = 'Set the local PHP version (project-specific). '
      'Without a version argument, uses the version from .php-version if present.';

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

  List<PhpVersion> _getAvailableVersions() {
    final versionStrings =
        _osManager.getAvailableVersions(_osManager.phpVersionsPath);
    return versionStrings.map((v) => PhpVersion.parse(v)).toList();
  }

  @override
  Future<int> run() async {
    try {
      final project = await Project.findFromCurrentDirectory();
      final registry = VersionRegistry(_osManager);

      // Always ensure .gitignore includes .pvm
      await _gitIgnoreService.ensureGitignoreIncludesPvm(
        rootPath: project.rootDirectory.path,
      );

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
        rootPath: project.rootDirectory.path);

    if (configured == null) {
      _console
          .printError('No version specified and no .php-version file found.');
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
    final available = _getAvailableVersions();

    // Check if version is in available list
    if (!available.any((v) => v == requestedVersion)) {
      if (_console.hasTerminal) {
        final picked = await _phpVersionManager.promptVersionPick(
          availableVersions: available,
        );
        if (picked == null) {
          _console.print('Cancelled.');
          return ExitCode.userCancelled;
        }
        // Recursively call with the same updateFile flag
        return _useSpecificVersion(project, picked, registry,
            updateFile: updateFile);
      } else {
        _console.printError(
            'Requested version $requestedVersion is not available.');
        return ExitCode.versionNotFound;
      }
    }

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
        return _applyVersion(project, requestedVersion, registry,
            updateFile: true);
      } else {
        // Non-interactive: apply but don't update file
        return _applyVersion(project, requestedVersion, registry,
            updateFile: false);
      }
    }

    // No mismatch or same version: apply with caller's updateFile preference
    return _applyVersion(project, requestedVersion, registry,
        updateFile: updateFile);
  }

  Future<int> _applyVersion(
    Project project,
    PhpVersion version,
    VersionRegistry registry, {
    required bool updateFile,
  }) async {
    final localPath =
        p.join(project.rootDirectory.path, PvmConstants.pvmDirName);
    final sourcePath = registry.getVersionPath(version);

    try {
      if (!await _osManager.directoryExists(sourcePath)) {
        _console.printError('Version directory not found at $sourcePath');
        return ExitCode.versionNotFound;
      }

      // Use the activator to create the local symlink
      await _versionActivator.activateLocal(version.toString());

      if (updateFile) {
        await _phpVersionManager.writeCurrentVersion(
          rootPath: project.rootDirectory.path,
          version: version,
        );
      }

      _console.print('Local link created: $localPath -> $sourcePath');
      return ExitCode.success;
    } catch (e) {
      _console.printError('Error: $e');
      return ExitCode.generalError;
    }
  }
}
