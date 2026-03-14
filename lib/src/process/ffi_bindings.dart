import 'dart:ffi';

export 'dart:ffi' show sizeOf, nullptr;
export 'package:ffi/ffi.dart' show calloc;
export 'package:win32/win32.dart' hide StringUtf8Pointer show
    CreateJobObject,
    CloseHandle,
    SetInformationJobObject,
    PROCESS_SET_QUOTA,
    PROCESS_TERMINATE,
    OpenProcess,
    FALSE,
    GetLastError,
    TerminateJobObject;

// Looked up once at startup — not available via package:win32 directly.
final assignProcessToJobObject = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<IntPtr Function(IntPtr, IntPtr), int Function(int, int)>('AssignProcessToJobObject');

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
