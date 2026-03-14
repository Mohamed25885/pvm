import 'dart:async';
import 'dart:io';

import 'job_object_manager.dart';

class ManagedProcessRunner {
  JobObjectManager? _jobManager;
  Process? _process;
  StreamSubscription? _signalSubscription;
  StreamSubscription? _stdoutSubscription;
  StreamSubscription? _stderrSubscription;
  bool _running = false;

  Future<int> run(String executablePath, List<String> args) async {
    if (_running) {
      throw StateError('A process is already running');
    }
    _running = true;

    try {
      _jobManager = JobObjectManager();

      if (!_jobManager!.create()) {
        stderr.writeln(
            '[warn] Failed to create Job Object — child processes may outlive parent');
        _jobManager = null;
      }

      _process = await _startWithRetry(executablePath, args);

      _stdoutSubscription =
          _process!.stdout.listen((data) => stdout.add(data));
      _stderrSubscription =
          _process!.stderr.listen((data) => stderr.add(data));

      if (_jobManager != null && _jobManager!.isValid) {
        _jobManager!.assignProcess(_process!.pid);
      }

      _setupSignalHandler();

      final exitCode = await _process!.exitCode;

      _cleanup();

      return exitCode;
    } finally {
      _running = false;
    }
  }

  Future<Process> _startWithRetry(
    String executablePath,
    List<String> args, {
    int maxAttempts = 3,
    Duration delay = const Duration(milliseconds: 50),
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await Process.start(
          executablePath,
          args,
          mode: ProcessStartMode.normal,
        );
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        stderr.writeln(
            '[warn] Process.start failed (attempt $attempt/$maxAttempts): $e — retrying in ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      }
    }
    throw StateError('unreachable');
  }

  void _setupSignalHandler() {
    _signalSubscription?.cancel();
    _signalSubscription =
        ProcessSignal.sigint.watch().listen((_) async {
      await _killProcessTree();
    });
  }

  Future<void> _killProcessTree() async {
    if (_process != null) {
      await Process.run(
          'taskkill', ['/pid', _process!.pid.toString(), '/t', '/f']);
    }
  }

  void _cleanup() {
    _signalSubscription?.cancel();
    _signalSubscription = null;

    _stdoutSubscription?.cancel();
    _stdoutSubscription = null;

    _stderrSubscription?.cancel();
    _stderrSubscription = null;

    _jobManager?.dispose();
    _jobManager = null;
    _process = null;
  }

  void dispose() {
    _cleanup();
  }
}
