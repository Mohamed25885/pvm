import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pvm/src/core/os_manager.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/core/platform_info.dart';

class IOProcessManager implements IProcessManager {
  final IOSManager _osManager;
  final PlatformInfo _platform;

  IOProcessManager({required IOSManager osManager, PlatformInfo? platformInfo})
    : _osManager = osManager,
      _platform = platformInfo ?? createPlatformInfo();

  bool get _isWindows => _platform.osType == 'windows';

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    final executable = await resolveSystemCommand(spec.executable);
    final process = await Process.start(
      executable,
      spec.arguments,
      workingDirectory: spec.workingDirectory,
      environment: spec.environment,
      mode: ProcessStartMode.inheritStdio,
    );

    // For interactive processes, we let Dart handle the stdio directly via inheritStdio.
    // This is simpler and more reliable than manual piping, especially for
    // long-running processes like `php artisan serve`.
    // The process will terminate when the child terminates.
    return await process.exitCode;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    try {
      final executable = await resolveSystemCommand(spec.executable);
      final result = await Process.run(
        executable,
        spec.arguments,
        workingDirectory: spec.workingDirectory,
        environment: spec.environment,
        runInShell: false,
      );

      return CapturedProcessResult(
        stdout: result.stdout?.toString() ?? '',
        stderr: result.stderr?.toString() ?? '',
        exitCode: result.exitCode,
      );
    } on ProcessException catch (error) {
      throw Exception(
        'Failed to start process "${spec.executable}": ${error.message}',
      );
    }
  }

  @override
  Future<String> resolveSystemCommand(String command) async {
    if (command.isEmpty) {
      throw ArgumentError.value(command, 'command', 'must not be empty');
    }

    if (_containsPathSeparator(command)) {
      return command;
    }

    final mappedPath = await _resolveMappedCommandPath(command);
    if (mappedPath != null) {
      return mappedPath;
    }

    final resolvedInPath = await _findCommandInPath(command);
    if (resolvedInPath == null) {
      // Never hand a bare name to the OS: on Windows CreateProcess would
      // search the current directory before PATH (S10).
      throw ProcessException(command, const [], 'Command not found on PATH');
    }
    return resolvedInPath;
  }

  bool _containsPathSeparator(String command) {
    if (_isWindows) {
      return command.contains('\\') || command.contains('/');
    }
    return command.contains('/');
  }

  Future<String?> _resolveMappedCommandPath(String command) async {
    final candidates = _commandResolutionMap[command.toLowerCase()] ?? const [];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }

  Future<String?> _findCommandInPath(String command) async {
    final pathValue = _osManager.currentEnvironment['PATH'];
    if (pathValue == null || pathValue.trim().isEmpty) {
      return null;
    }

    final separator = _platform.pathSeparator;
    final dirs = pathValue.split(separator).where((d) => d.trim().isNotEmpty);
    final hasExtension = p.extension(command).isNotEmpty;

    final extensions = _isWindows
        ? _windowsExecutableExtensions()
        : const <String>[''];

    for (final dir in dirs) {
      final baseDir = dir.replaceAll('"', '').trim();
      if (baseDir.isEmpty || !p.isAbsolute(baseDir)) continue;

      if (hasExtension) {
        final candidate = p.join(baseDir, command);
        if (await File(candidate).exists()) {
          return candidate;
        }
        continue;
      }

      for (final ext in extensions) {
        final candidate = p.join(baseDir, '$command$ext');
        if (await File(candidate).exists()) {
          return candidate;
        }
      }
    }

    return null;
  }

  List<String> _windowsExecutableExtensions() {
    final pathExtRaw = _osManager.currentEnvironment['PATHEXT'];
    final raw = (pathExtRaw == null || pathExtRaw.trim().isEmpty)
        ? '.EXE;.BAT;.CMD;.COM'
        : pathExtRaw;

    final parts = raw
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return parts
        .map((e) => e.startsWith('.') ? e.toLowerCase() : '.${e.toLowerCase()}')
        .toList();
  }

  static const Map<String, List<String>> _commandResolutionMap = {
    'apt-get': ['/usr/bin/apt-get', '/bin/apt-get'],
    'brew': ['/opt/homebrew/bin/brew', '/usr/local/bin/brew', '/usr/bin/brew'],
  };
}
