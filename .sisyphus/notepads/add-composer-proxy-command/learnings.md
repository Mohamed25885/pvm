# Learnings

## Pattern Discoveries

- `IProcessManager` interface has methods: `runInteractive(ProcessSpec)` and `runCaptured(ProcessSpec)`.
- `IOSManager` does **NOT** provide `currentEnvironment`; we use `Platform.environment` directly.
- Existing test doubles like `MockOSManager` live in `lib/src/managers/` but our new fakes should be in `test/` (SOLID separation).
- `ProcessSpec` fields: `executable`, `arguments`, `workingDirectory`, `environment` (nullable, defaults to null which means inherit).
- The project uses `package:path` as `p` for path joins; but simple string interpolation works for fixed patterns.
- All file checks in new code must use `_osManager.fileExists()` (async) not `File(...).existsSync()`.

## Successful Approaches

- Created `PhpExecutor` service with two public methods: `runPhp` and `runScript`.
- Used `workingDirectory` override pattern: fallback to `_osManager.currentDirectory` if null.
- Built `ProcessSpec` with environment from `Platform.environment` (since OS manager doesn't provide it).
- Private `_resolvePhpExecutable` constructs platform-specific path and throws if missing.
- Test fakes: `FakeProcessManager` captures specs and returns configurable exit code; `FakeOSManager` provides `fileExists` map and `currentDirectory`.
- Tests verify spec fields (executable, arguments, workingDirectory, environment) and error conditions.

## Key Code Structure

```dart
class PhpExecutor {
  Future<int> runPhp(List<String> args, {String? workingDirectory}) async {
    final rootPath = workingDirectory ?? _osManager.currentDirectory;
    final phpExe = await _resolvePhpExecutable(rootPath);
    final spec = ProcessSpec(
      executable: phpExe,
      arguments: args,
      workingDirectory: rootPath,
      environment: Platform.environment,
    );
    return await _processManager.runInteractive(spec);
  }

  Future<int> runScript(String scriptPath, List<String> args, ...) async {
    // similar, arguments: [scriptPath, ...args]
  }

  Future<String> _resolvePhpExecutable(String rootPath) async {
    final phpExe = Platform.isWindows ? '$rootPath\\.pvm\\php.exe' : '$rootPath/.pvm/php';
    if (!(await _osManager.fileExists(phpExe))) {
      throw Exception('PHP executable not found at $phpExe');
    }
    return phpExe;
  }
}
```

---

# Issues

## Problem: Subagent Non-Delivery
- First subagent (ses_2df69da32ffe...) claimed completion but produced **zero files**; only boulder.json and .php-version changed.
- Had to detect failure via `git diff --stat` showing no implementation files.
- Had to resume same session and provide explicit, minimal-scope task to force creation.

## Problem: Existing php_executor.dart Had Bugs
- File already existed with wrong method calls: `_processManager.runInteractive` vs `interactive` confusion.
- Used `_osManager.currentEnvironment` which doesn't exist in `IOSManager`.
- We fixed by using `Platform.environment` and correct method name `runInteractive`.

## Problem: Test File Modifications
- The existing test file had both fake classes inside; requirement is to separate them into their own files per SOLID.
- Had to create `fake_process_manager.dart` and `fake_os_manager.dart` in `test/services/`.
- Then refactor `php_executor_test.dart` to import them.

---

# Decisions

## Design Decision: PhpExecutor Signature
- Constructor: `PhpExecutor({required IProcessManager processManager, required IOSManager osManager})` — named parameters for clarity.
- `runPhp` and `runScript` both return `Future<int>` exit code.
- `_resolvePhpExecutable` is `async` because `fileExists` is async; acceptable.

## Test Design Decision: Fake Classes Location
- Place fakes in separate files: `test/services/fake_process_manager.dart` and `test/services/fake_os_manager.dart`.
- Keep them simple: capture specs, allow configuration (mockExitCode, fileExistsMap, currentDirectory).
- Only implement methods needed by PhpExecutor tests; other IOSManager/IProcessManager methods throw `UnimplementedError`.

## Test Helper: getPhpExe()
- Helper function inside test file to compute platform-specific PHP path; avoids duplication.

---

# Problems / Unresolved

## Need to Refactor PhpCommand
- `lib/src/commands/php_command.dart` currently uses `IProcessManager` directly.
- Must update to accept `PhpExecutor` in constructor and delegate to it.
- Must ensure existing tests still pass after injection.

## Need to Update pvm.dart Wiring
- `pvm.dart` currently creates `IProcessManager` and passes to commands.
- Must now create `PhpExecutor` and pass that to `PhpCommand` and `ComposerCommand`.
- This is a breaking change to wiring but preserves external behavior.

## ComposerCommand Not Yet Implemented
- Still pending: create `composer_command.dart` with PATH lookup logic.
- Tests for ComposerCommand not written yet.

## README Update Pending
- Need to add `pvm composer` section with usage examples.

---
