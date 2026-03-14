import 'dart:io';

import 'package:args/command_runner.dart';

import 'interfaces/os_manager.dart';
import 'utils/windows_os_manager.dart';
import 'utils/job_object_manager.dart';

void main(List<String> arguments) async {
  final runner = PvmCommandRunner();
  try {
    await runner.run(arguments);
  } catch (e) {
    print(e.toString());
    exitCode = 1;
  }
}

class PvmCommandRunner extends CommandRunner<int> {
  late final IOSManager _osManager;
  late final PhpProcessRunner _phpRunner;

  PvmCommandRunner({IOSManager? osManager})
      : super('pvm', 'PHP Version Manager - Manage multiple PHP versions on Windows') {
    _osManager = osManager ?? WindowsOSManager();
    _phpRunner = PhpProcessRunner();
    
    addCommand(GlobalCommand(_osManager));
    addCommand(UseCommand(_osManager));
    addCommand(ListCommand(_osManager));
    addCommand(PhpCommand(_osManager, _phpRunner));
  }

  @override
  Future<int?> run(Iterable<String> args) async {
    if (args.isEmpty || args.any((arg) => arg == 'help' || arg == '--help' || arg == '-h')) {
      print(usage);
      return 0;
    }
    return super.run(args);
  }
}

class GlobalCommand extends Command<int> {
  @override
  final String name = 'global';
  
  @override
  final String description = 'Set the global PHP version (system-wide)';
  
  final IOSManager _osManager;

  GlobalCommand(this._osManager);

  @override
  Future<int> run() async {
    final version = argResults?.rest.firstOrNull;
    if (version == null) {
      print('Error: No version specified');
      return 1;
    }

    if (argResults?.rest.length != 1) {
      print('Error: Too many arguments. Usage: pvm global <version>');
      return 1;
    }

    final available = _osManager.getAvailableVersions(_osManager.phpVersionsPath);
    if (!available.contains(version)) {
      print('Error: Version $version not found. Available: ${available.join(", ")}');
      return 1;
    }

    try {
      final homeDir = _osManager.getHomeDirectory();
      final globalPath = '$homeDir\\.pvm';
      final sourcePath = '${_osManager.phpVersionsPath}\\$version';
      
      final result = await _osManager.createSymLink(version, sourcePath, globalPath);
      print('Global link created: ${result.to} -> ${result.from}');
      print('Add "$globalPath" to your PATH to use globally');
      return 0;
    } catch (e) {
      print('Error: $e');
      return 1;
    }
  }
}

class UseCommand extends Command<int> {
  @override
  final String name = 'use';
  
  @override
  final String description = 'Set the local PHP version (project-specific)';
  
  final IOSManager _osManager;

  UseCommand(this._osManager);

  @override
  Future<int> run() async {
    final version = argResults?.rest.firstOrNull;
    if (version == null) {
      print('Error: No version specified');
      return 1;
    }

    if (argResults?.rest.length != 1) {
      print('Error: Too many arguments. Usage: pvm use <version>');
      return 1;
    }

    final available = _osManager.getAvailableVersions(_osManager.phpVersionsPath);
    if (!available.contains(version)) {
      print('Error: Version $version not found. Available: ${available.join(", ")}');
      return 1;
    }

    try {
      final localPath = _osManager.localPath;
      final sourcePath = '${_osManager.phpVersionsPath}\\$version';
      
      final result = await _osManager.createSymLink(version, sourcePath, localPath);
      print('Local link created: ${result.to} -> ${result.from}');
      return 0;
    } catch (e) {
      print('Error: $e');
      return 1;
    }
  }
}

class ListCommand extends Command<int> {
  @override
  final String name = 'list';
  
  @override
  final String description = 'List all available PHP versions';
  
  final IOSManager _osManager;

  ListCommand(this._osManager);

  @override
  Future<int> run() async {
    final versions = _osManager.getAvailableVersions(_osManager.phpVersionsPath);
    if (versions.isEmpty) {
      print('No PHP versions found in ${_osManager.phpVersionsPath}');
      return 1;
    }
    print(versions.join('\n'));
    return 0;
  }
}

class PhpCommand extends Command<int> {
  @override
  final String name = 'php';
  
  @override
  final String description = 'Run PHP with the local version configuration';
  
  final IOSManager _osManager;
  final PhpProcessRunner _phpRunner;

  PhpCommand(this._osManager, this._phpRunner);

  @override
  String get invocation => 'pvm php [arguments]';

  @override
  Future<int> run() async {
    final localPath = _osManager.localPath;

    if (!await _osManager.directoryExists(localPath)) {
      print('Error: No local version configured. Run "pvm use <version>" first.');
      return 1;
    }

    final phpExe = '$localPath\\php.exe';
    if (!await _osManager.fileExists(phpExe)) {
      print('Error: PHP executable not found at $phpExe');
      return 1;
    }

    try {
      final args = argResults?.rest ?? [];
      final exitCode = await _phpRunner.run(phpExe, args);
      return exitCode;
    } catch (e) {
      print('Error running PHP: $e');
      return 1;
    }
  }
}
