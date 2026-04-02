import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/gitignore_service.dart';
import '../core/os_manager.dart';
import '../core/php_version_manager.dart';

class UseCommand extends Command<int> {
  @override
  final String name = 'use';

  @override
  final String description = 'Set the local PHP version (project-specific). '
      'Without a version argument, uses the version from .php-version if present.';

  final IOSManager _osManager;
  final PhpVersionManager _phpVersionManager;
  final GitIgnoreService _gitIgnoreService;

  UseCommand(
    this._osManager,
    this._phpVersionManager,
    this._gitIgnoreService,
  );

  /// Walk up from [cwd] looking for .php-version.
  /// If found, its parent directory is the project root.
  /// Otherwise fall back to [cwd].
  String _discoverRootPath(String cwd) {
    var dir = Directory(cwd);
    while (true) {
      if (dir.parent.path == dir.path) break; // filesystem root
      final phpVersionFile = File(p.join(dir.path, '.php-version'));
      if (phpVersionFile.existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return cwd;
  }

  @override
  Future<int> run() async {
    final cwd = Directory.current.path;
    final rootPath = _discoverRootPath(cwd);
    final requestedVersion = argResults?.rest.firstOrNull;

    // -- Run GitIgnoreService on every use --
    await _gitIgnoreService.ensureGitignoreIncludesPvm(rootPath: rootPath);

    // -- No argument: use .php-version if present --
    if (requestedVersion == null) {
      final lastVersion =
          await _phpVersionManager.readLastUsedVersion(rootPath: rootPath);
      if (lastVersion == null) {
        print('Error: No version specified and no .php-version file found.');
        print('Usage: pvm use <version>');
        return 1;
      }
      return _applyVersion(rootPath, lastVersion, updateFile: true);
    }

    // -- Too many arguments --
    if (argResults!.rest.length != 1) {
      print('Error: Too many arguments. Usage: pvm use <version>');
      return 1;
    }

    // -- Version format validation --
    final versionPattern = RegExp(r'^\d+\.\d+(\.\d+)?$');
    if (!versionPattern.hasMatch(requestedVersion)) {
      print(
          'Error: Invalid version format. Expected: x.y or x.y.z (e.g., 8.2, 8.2.1)');
      return 1;
    }

    // -- Check if requested version is installed --
    final available =
        _osManager.getAvailableVersions(_osManager.phpVersionsPath);
    if (!available.contains(requestedVersion)) {
      // -- Version not installed: prompt user to pick --
      print('Error: Version $requestedVersion not found.');
      final picked = await _phpVersionManager.promptVersionPick(
        availableVersions: available,
      );
      if (picked == null) {
        print('Cancelled.');
        return 1;
      }
      return _applyVersion(rootPath, picked, updateFile: true);
    }

    // -- Check for mismatch with .php-version --
    final lastVersion =
        await _phpVersionManager.readLastUsedVersion(rootPath: rootPath);
    if (lastVersion != null && lastVersion != requestedVersion) {
      final isInteractive = stdout.hasTerminal;
      if (isInteractive) {
        final confirmed = await _phpVersionManager.promptMismatch(
          currentVersion: lastVersion,
          requestedVersion: requestedVersion,
        );
        if (!confirmed) {
          print('Cancelled.');
          return 1;
        }
        // Interactive confirmed: apply and update .php-version
        return _applyVersion(rootPath, requestedVersion, updateFile: true);
      } else {
        // Non-interactive: auto-apply but do NOT update .php-version
        return _applyVersion(rootPath, requestedVersion, updateFile: false);
      }
    }

    // -- No mismatch or same version: apply and update .php-version --
    return _applyVersion(rootPath, requestedVersion, updateFile: true);
  }

  /// Create the local symlink and optionally update .php-version.
  Future<int> _applyVersion(
    String rootPath,
    String version, {
    required bool updateFile,
  }) async {
    final localPath = p.join(rootPath, '.pvm');
    final sourcePath = p.join(_osManager.phpVersionsPath, version);

    try {
      if (!await _osManager.directoryExists(sourcePath)) {
        print('Error: Version directory not found at $sourcePath');
        return 1;
      }

      final result = await _osManager.createSymLink(
        version,
        sourcePath,
        localPath,
      );

      if (updateFile) {
        await _phpVersionManager.writeCurrentVersion(
          rootPath: rootPath,
          version: version,
        );
      }

      print('Local link created: ${result.to} -> ${result.from}');
      return 0;
    } catch (e) {
      print('Error: $e');
      return 1;
    }
  }
}
