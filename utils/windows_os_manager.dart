import 'dart:io';
import 'package:path/path.dart' as p;

import '../interfaces/os_manager.dart';

class WindowsOSManager implements IOSManager {
  @override
  String get programDirectory => File(Platform.script.toFilePath()).parent.path;

  @override
  String get phpVersionsPath => "$programDirectory\\versions";

  @override
  String get localPath => "${Directory.current.path}\\.pvm";
  
  String get directoryName => '.pvm';

  @override
  String getHomeDirectory() {
    final home = Platform.environment['USERPROFILE'] ?? 
                 Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw Exception('Could not determine home directory');
    }
    return home;
  }

  @override
  Future<({String from, String to})> createSymLink(String version, String from, String to) async {
    final homeDir = Directory(to).parent;

    if (homeDir.path.isEmpty || !(await directoryExists(homeDir.path))) {
      throw Exception('Error: Could not determine home directory.');
    }
    if (from.isEmpty || !(await directoryExists(from))) {
      throw Exception('Error: Source directory does not exist: $from');
    }

    try {
      Process.runSync('cmd', ['/c', 'rmdir', to]);
    } catch (_) {}

    final result = await Process.run('cmd', [
      '/c',
      'mklink',
      '/D',
      to,
      from,
    ]);

    if (result.exitCode == 0) {
      return (from: from, to: to);
    }

    throw Exception('Error creating symbolic link: ${result.stderr}');
  }

  @override
  Future<bool> directoryExists(String path) async {
    return await Directory(path).exists();
  }

  @override
  Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  @override
  List<String> getAvailableVersions(String versionsPath) {
    if (!Directory(versionsPath).existsSync()) {
      return [];
    }
    return Directory(versionsPath)
        .listSync()
        .where((FileSystemEntity entity) => entity is Directory)
        .map((FileSystemEntity entity) => p.basename(entity.path))
        .toList();
  }
}

class WindowsProcessManager implements IProcessManager {
  @override
  Future<int> runPhp(List<String> args, String phpPath) async {
    final phpExe = '$phpPath\\php.exe';
    
    if (!(await File(phpExe).exists())) {
      throw Exception("No PHP executable found at: $phpExe");
    }

    final process = await Process.start(
      phpExe,
      args,
      mode: ProcessStartMode.inheritStdio,
    );

    return await process.exitCode;
  }

  @override
  Future<({int pid, int exitCode})> startProcess(String executable, List<String> args) async {
    final process = await Process.start(
      executable,
      args,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;
    return (pid: process.pid, exitCode: exitCode);
  }

  @override
  Future<void> killProcessTree(int pid) async {
    await Process.run('taskkill', ['/pid', pid.toString(), '/t', '/f']);
  }
}
