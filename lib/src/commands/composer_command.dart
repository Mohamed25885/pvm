import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/os_manager.dart';
import '../services/php_executor.dart';

class ComposerCommand extends Command<int> {
  @override
  final String name = 'composer';

  @override
  final String description = 'Run Composer using the local PHP version';

  final IOSManager _osManager;
  final PhpExecutor _phpExecutor;

  ComposerCommand(this._osManager, this._phpExecutor);

  @override
  String get invocation => 'pvm composer [arguments]';

  @override
  ArgParser get argParser => ArgParser.allowAnything();

  @override
  Future<int> run() async {
    final cwd = _osManager.currentDirectory;
    final rootPath = _discoverRootPath(cwd);
    final args = argResults?.rest ?? [];
    return await _executeComposer(rootPath, args);
  }

  /// Executes Composer with the given [args] and [rootPath].
  /// Used by [run] and for testing.
  Future<int> runWithArgs(List<String> args, {String? rootPath}) async {
    final cwd = rootPath ?? _osManager.currentDirectory;
    final resolvedRootPath = rootPath ?? _discoverRootPath(cwd);
    return await _executeComposer(resolvedRootPath, args);
  }

  Future<int> _executeComposer(String rootPath, List<String> args) async {
    // Ensure local PHP version is set (.pvm exists)
    final localPvm = p.join(rootPath, '.pvm');
    if (!await _osManager.directoryExists(localPvm)) {
      print('Error: No local PHP version set. Run "pvm use <version>" first.');
      return 1;
    }

    // Find Composer script in PATH
    final composerScript = await _findComposerScript();
    if (composerScript == null) {
      print('Error: Composer not found in PATH.');
      print(
          'Install Composer globally or ensure composer.phar is in your PATH.');
      return 1;
    }

    try {
      return await _phpExecutor.runScript(composerScript, args,
          workingDirectory: rootPath);
    } catch (e) {
      print('Error running Composer: $e');
      return 1;
    }
  }

  /// Walk up from [cwd] looking for .php-version file.
  /// Returns project root or falls back to [cwd].
  String _discoverRootPath(String cwd) {
    var dir = Directory(cwd);
    while (true) {
      final phpVersionFile = File(p.join(dir.path, '.php-version'));
      if (phpVersionFile.existsSync()) {
        return dir.path;
      }
      if (dir.parent.path == dir.path) break;
      dir = dir.parent;
    }
    return cwd;
  }

  /// Searches the PATH environment for a Composer executable.
  ///
  /// On Windows, looks for `composer.bat`, `composer.cmd`, or `composer.phar`.
  /// On Unix, looks for `composer` or `composer.phar`.
  ///
  /// If a batch file is found, also checks for `composer.phar` in the same
  /// directory (standard Composer-Setup layout). Returns the path to the
  /// composer.phar file if found, otherwise the batch/phar itself.
  Future<String?> _findComposerScript() async {
    final pathEnv = _osManager.currentEnvironment['PATH'] ?? '';
    final separator = Platform.isWindows ? ';' : ':';
    final dirs = pathEnv.split(separator);

    final candidates = Platform.isWindows
        ? ['composer.bat', 'composer.cmd', 'composer.phar']
        : ['composer', 'composer.phar'];

    for (final dir in dirs) {
      for (final name in candidates) {
        final candidate = p.join(dir, name);
        if (await _osManager.fileExists(candidate)) {
          if (candidate.endsWith('.bat') || candidate.endsWith('.cmd')) {
            // Look for composer.phar in same directory
            final phar = p.join(dir, 'composer.phar');
            if (await _osManager.fileExists(phar)) {
              return phar;
            }
            // Batch file without .phar: skip because it would use system PHP
            continue;
          }
          return candidate;
        }
      }
    }
    return null;
  }
}
