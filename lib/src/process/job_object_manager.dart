import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

final assignProcessToJobObject = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<IntPtr Function(IntPtr, IntPtr), int Function(int, int)>(
        'AssignProcessToJobObject');

final class JOBOBJECT_BASIC_LIMIT_INFORMATION extends Struct {
  @Int64()
  external int PerProcessUserTimeLimit;

  @Int64()
  external int PerJobUserTimeLimit;

  @Uint32()
  external int LimitFlags;

  @UintPtr()
  external int MinimumWorkingSetSize;

  @UintPtr()
  external int MaximumWorkingSetSize;

  @Uint32()
  external int ActiveProcessLimit;

  @Int64()
  external int Affinity;

  @Uint32()
  external int PriorityClass;

  @Uint32()
  external int SchedulingClass;
}

final class IO_COUNTERS extends Struct {
  @Uint64()
  external int ReadOperationCount;

  @Uint64()
  external int WriteOperationCount;

  @Uint64()
  external int OtherOperationCount;

  @Uint64()
  external int ReadTransferCount;

  @Uint64()
  external int WriteTransferCount;

  @Uint64()
  external int OtherTransferCount;
}

final class JOBOBJECT_EXTENDED_LIMIT_INFORMATION extends Struct {
  external JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
  external IO_COUNTERS IoInfo;

  @UintPtr()
  external int ProcessMemoryLimit;

  @UintPtr()
  external int JobMemoryLimit;

  @UintPtr()
  external int PeakProcessMemoryUsed;

  @UintPtr()
  external int PeakJobMemoryUsed;
}

class JobObjectLimits {
  static const int JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000;
}

class JobObjectInfoClass {
  static const int JobObjectExtendedLimitInformation = 9;
}

// Windows error codes returned by GetLastError()
class _WinError {
  static const int accessDenied = 5; // ERROR_ACCESS_DENIED
  static const int invalidHandle = 6; // ERROR_INVALID_HANDLE
}

class JobObjectManager {
  int _jobHandle = 0;
  bool _disposed = false;

  int get handle => _jobHandle;
  bool get isValid => _jobHandle != 0;

  bool create() {
    if (_disposed) {
      throw StateError('JobObjectManager has been disposed');
    }

    _jobHandle = CreateJobObject(nullptr, nullptr);
    if (_jobHandle == 0) {
      return false;
    }

    if (!_configureKillOnJobClose()) {
      CloseHandle(_jobHandle);
      _jobHandle = 0;
      return false;
    }

    return true;
  }

  bool _configureKillOnJobClose() {
    final pInfo = calloc<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>();

    try {
      // calloc zero-initialises memory — only set the flag that matters.
      pInfo.ref.BasicLimitInformation.LimitFlags =
          JobObjectLimits.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

      final result = SetInformationJobObject(
        _jobHandle,
        JobObjectInfoClass.JobObjectExtendedLimitInformation,
        pInfo.cast(),
        sizeOf<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>(),
      );

      return result != 0;
    } finally {
      calloc.free(pInfo);
    }
  }

  /// Assigns [processId] to this job object.
  ///
  /// Returns true on success. Returns false on benign races where the process
  /// exited before or during assignment (ERROR_ACCESS_DENIED / ERROR_INVALID_HANDLE).
  /// These are expected under rapid-spawn load — the process was so short-lived
  /// that job containment is irrelevant. Any unexpected error is also logged.
  bool assignProcess(int processId) {
    if (!isValid) return false;

    const accessRights = PROCESS_SET_QUOTA | PROCESS_TERMINATE;
    final processHandle = OpenProcess(accessRights, FALSE, processId);

    if (processHandle == 0) {
      // Process already exited before we could open a handle — benign race.
      final err = GetLastError();
      stderr.writeln(
          '[warn] OpenProcess($processId) failed (err=$err) — process may have already exited');
      return false;
    }

    final assignResult = assignProcessToJobObject(_jobHandle, processHandle);
    CloseHandle(processHandle);

    if (assignResult == 0) {
      final err = GetLastError();

      // Benign races under rapid spawning:
      //   ERROR_ACCESS_DENIED (5)  — process exited mid-assignment (0xC0000005)
      //   ERROR_INVALID_HANDLE (6) — handle became invalid between open and assign
      if (err == _WinError.accessDenied || err == _WinError.invalidHandle) {
        stderr.writeln(
            '[warn] AssignProcessToJobObject($processId) benign race (err=$err) — process exited during assignment');
        return false;
      }

      // Unexpected error — surface it clearly.
      stderr.writeln(
          '[warn] AssignProcessToJobObject($processId) failed unexpectedly (err=$err)');
      return false;
    }

    return true;
  }

  bool terminate([int exitCode = 1]) {
    if (!isValid) return false;
    final result = TerminateJobObject(_jobHandle, exitCode);
    return result != 0;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;

    if (isValid) {
      CloseHandle(_jobHandle);
      _jobHandle = 0;
    }
  }
}

/// A generic managed process runner that uses Windows Job Objects to ensure
/// child processes are terminated when the parent exits.
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

      _stdoutSubscription = _process!.stdout.listen((data) => stdout.add(data));
      _stderrSubscription = _process!.stderr.listen((data) => stderr.add(data));

      if (_jobManager != null && _jobManager!.isValid) {
        // assignProcess handles the 0xC0000005 race internally —
        // a false return is benign for short-lived processes.
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

  /// Attempts to start the process up to [maxAttempts] times.
  ///
  /// On Windows, rapid concurrent process creation can transiently fail with
  /// 0xC0000005 (access violation) due to OS-level CreateProcess congestion.
  /// A short backoff between retries is enough to clear the contention.
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
    _signalSubscription = ProcessSignal.sigint.watch().listen((_) async {
      await _killProcessTree();
    });
  }

  Future<void> _killProcessTree() async {
    if (_process != null) {
      // Don't null _process here — let _cleanup() own that.
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
