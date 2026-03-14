import 'dart:ffi';
import 'dart:io';

import 'ffi_bindings.dart';
import 'job_object_constants.dart';

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

  bool assignProcess(int processId) {
    if (!isValid) return false;

    const accessRights = PROCESS_SET_QUOTA | PROCESS_TERMINATE;
    final processHandle = OpenProcess(accessRights, FALSE, processId);

    if (processHandle == 0) {
      final err = GetLastError();
      stderr.writeln(
          '[warn] OpenProcess($processId) failed (err=$err) — process may have already exited');
      return false;
    }

    final assignResult = assignProcessToJobObject(_jobHandle, processHandle);
    CloseHandle(processHandle);

    if (assignResult == 0) {
      final err = GetLastError();

      if (err == WinError.accessDenied || err == WinError.invalidHandle) {
        stderr.writeln(
            '[warn] AssignProcessToJobObject($processId) benign race (err=$err) — process exited during assignment');
        return false;
      }

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
