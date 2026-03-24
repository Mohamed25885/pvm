import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/os_manager.dart';
import '../services/php_executor.dart';

class PhpCommand extends Command<int> {
  @override
  final String name = 'php';

  @override
  final String description = 'Run PHP with the local version configuration';

  final IOSManager _osManager;
  final PhpExecutor _phpExecutor;

  PhpCommand(this._osManager, this._phpExecutor);

  /// Walk up from [cwd] looking for .php-version file.
  /// Its parent directory is the project root.
  /// Falls back to [cwd] if not found.
  String _discoverRootPath(String cwd) {
    var dir = Directory(cwd);
    while (true) {
      // Check .php-version in the current directory being examined
      final phpVersionFile = File('${dir.path}\\.php-version');
      if (phpVersionFile.existsSync()) {
        return dir.path;
      }
      // Move to parent
      if (dir.parent.path == dir.path) break; // filesystem root
      dir = dir.parent;
    }
    return cwd;
  }

  @override
  String get invocation => 'pvm php [arguments]';

  @override
  ArgParser get argParser => ArgParser.allowAnything();

  @override
  Future<int> run() async {
    final cwd = _osManager.currentDirectory;
    final rootPath = _discoverRootPath(cwd);

    try {
      final args = argResults?.rest ?? [];
      final exitCode =
          await _phpExecutor.runPhp(args, workingDirectory: rootPath);
      return exitCode;
    } catch (e) {
      print('Error running PHP: $e');
      return 1;
    }
  }
}
