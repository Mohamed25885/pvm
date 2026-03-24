## 2026-03-23

- Implemented `IOProcessManager.runInteractive` with `Process.start(..., mode: ProcessStartMode.normal)` and explicit `stdout.addStream`/`stderr.addStream` forwarding so streams are fully consumed before returning.
- Kept stdin passthrough as private best-effort piping; failures are swallowed to avoid platform-coupled behavior in the cross-platform runtime path.
- Added deterministic interactive tests by launching temporary Dart scripts via `Platform.resolvedExecutable`, asserting exit-code passthrough and `workingDirectory`/`environment` propagation through `ProcessSpec`.
- Implemented `IOProcessManager.runCaptured` via `Process.run` with `runInShell: false`, preserving `workingDirectory` and `environment`, returning separate `stdout`/`stderr` plus exact `exitCode` through `CapturedProcessResult`.
- Added captured-path tests that verify split stream capture, non-inherited terminal behavior, non-zero exit-code passthrough, and clear process-start failure messaging.
- Retired the legacy Windows-only managed runner stack from production path by deleting `managed_process_runner.dart`, `job_object_manager.dart`, `ffi_bindings.dart`, and `job_object_constants.dart`, and narrowing `lib/src/process/process.dart` to export only `io_process_manager.dart`.
- Confirmed `lib/src/` has no remaining `ManagedProcessRunner`, `JobObjectManager`, `taskkill`, or `AssignProcessToJobObject` references after cleanup.
