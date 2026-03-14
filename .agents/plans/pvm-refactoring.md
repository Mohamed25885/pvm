# PVM Refactoring Plan

## Status

**Done**

---

## Description

Refactor the PVM (PHP Version Manager) codebase to improve maintainability, testability, and performance. This involves:

1. **Architecture**: Migrate from manual argument parsing to `CommandRunner` pattern
2. **Testing**: Create an OS Abstraction Layer (HAL) to enable testing on WSL/Linux
3. **Performance**: Fix high-latency/long-running process issues in PHP proxy using `inheritStdio`
4. **Reliability**: Add comprehensive tests including adversarial edge cases

---

## Phases

### Phase 1: Infrastructure Setup

**Status:** Done  
**Description:** Add testing dependencies and create test directory structure.

**Steps:**

1. Update `pubspec.yaml` to add `test: ^1.24.0` and `mocktail: ^1.0.3` to dev_dependencies
2. Run `dart pub get` to install dependencies
3. Create `test/` directory

---

### Phase 2: OS Abstraction Layer (HAL)

**Status:** Done  
**Description:** Create interfaces and implementations to decouple Windows-specific logic from business logic, enabling testing on WSL.

**Steps:**

1. Create `interfaces/os_manager.dart`:
   - Define `IOSManager` interface with methods: `createSymLink`, `directoryExists`, `fileExists`, `getAvailableVersions`, path getters
   - Define `IProcessManager` interface with methods: `runPhp`, `startProcess`, `killProcessTree`

2. Create `utils/windows_os_manager.dart`:
   - Implement `WindowsOSManager` class using `dart:io`
   - Implement `WindowsProcessManager` class

3. Create `utils/mock_os_manager.dart`:
   - Implement `MockOSManager` with configurable flags: `shouldThrowOnSymlink`, `shouldThrowOnDirectoryExists`, `shouldThrowOnFileExists`, `mockVersions`
   - Implement `MockProcessManager` for testing

4. Create `utils/job_object_manager.dart`:
   - Implement `PhpProcessRunner` class using `ProcessStartMode.inheritStdio` for high-performance piping

---

### Phase 3: CommandRunner Refactoring

**Status:** Done  
**Description:** Replace manual argument parsing and if-else chain with modular CommandRunner pattern.

**Steps:**

1. Refactor `pvm.dart`:
   - Create `PvmCommandRunner` extending `CommandRunner<int>`
   - Create `GlobalCommand` - sets system-wide PHP version via symlink in USERPROFILE
   - Create `UseCommand` - sets project-local PHP version via .pvm directory
   - Create `ListCommand` - lists available PHP versions from versions/ directory
   - Create `PhpCommand` - runs PHP with local configuration

2. Implement proper argument validation:
   - Check for missing version arguments
   - Validate version exists before symlink creation
   - Handle help flags (-h, --help, help)

3. Make `PvmCommandRunner` testable by accepting optional `IOSManager` parameter

---

### Phase 4: High-Performance Proxy Implementation

**Status:** Done  
**Description:** Fix latency issues with long-running processes (e.g., `php artisan serve`) by using native stdio inheritance.

**Steps:**

1. In `PhpProcessRunner.run()`:
   - Use `ProcessStartMode.inheritStdio` instead of manual stream piping
   - This allows PHP to communicate directly with terminal
   - Correctly handles interactive prompts and terminal colors

2. (Optional Future) Implement Windows Job Objects:
   - Use `win32` FFI to create Job Object
   - Configure to kill child processes when parent exits
   - Prevents zombie processes when terminal closes

---

### Phase 5: Baseline Testing

**Status:** Done  
**Description:** Create initial tests to verify current functionality works after refactoring.

**Steps:**

1. Create `test/mock_test.dart`:
   - Test `IOSManager` interface: `getAvailableVersions`, `getProgramDirectory`, `getLocalPath`, `getHomeDirectory`
   - Test `createSymLink` returns correct tuple
   - Test `directoryExists` and `fileExists` with mock paths
   - Test `IProcessManager`: `runPhp`, `startProcess`, `killProcessTree`
   - Test error handling: throw when flags are set

2. Run tests: `dart test` (should pass with 15 tests)

---

### Phase 6: Code Review & Fixes

**Status:** Done  
**Description:** Invoke review subagent to identify issues and fix critical bugs.

**Steps:**

1. Invoke **Review Subagent**:
   - Analyze architecture soundness
   - Check for memory leaks or logic errors
   - Verify adherence to AGENTS.md guidelines

2. Fix critical issues identified:
   - Fix help flag detection (`args.contains('help')` → `args.any((arg) => arg == 'help')`)
   - Add constructor parameter for `IOSManager` injection
   - Add argument count validation (too many arguments)
   - Fix nullable `argResults` handling

3. Run `dart analyze` to verify 0 errors

---

### Phase 7: Adversarial Testing

**Status:** Done  
**Description:** Create comprehensive edge case tests to ensure robustness.

**Steps:**

1. Invoke **Testing Subagent** to create `test/adversarial_test.dart`:

2. Test categories:
   - **Invalid Version Handling**: Non-existent, empty, special characters, path traversal
   - **Permission Errors**: Symlink failure, directory/file existence failures
   - **Argument Parsing**: No args, help flags, too many args, unknown commands
   - **PHP Command Edge Cases**: Missing .pvm dir, no php.exe, process failures
   - **Race Conditions**: Version deleted between check and use
   - **Empty/Null Data**: Empty versions list, empty paths, whitespace
   - **List Command**: Single version, many versions, unsorted
   - **Case Sensitivity**: Version uppercase, command case

3. Run tests: `dart test` (should pass with 85 tests total)

---

### Phase 8: Documentation Update

**Status:** Done  
**Description:** Update AGENTS.md with new architecture and guidelines.

**Steps:**

1. Update `AGENTS.md` to include:
   - Architecture section explaining HAL and CommandRunner
   - Critical Commands (analyze, format, test, build)
   - Code Style & Guidelines (imports, naming, types, error handling)
   - Testing Guidelines (use MockOSManager for WSL)
   - Common Pitfalls (Developer Mode, path separators)
   - Project Structure overview

---

## Conclusion

This refactoring transforms PVM from a monolithic script to a modular, testable application. The OS Abstraction Layer enables WSL testing, the CommandRunner pattern makes adding new commands trivial, and the high-performance proxy fixes long-standing issues with `php artisan serve`.

**Final Results:**

- `dart analyze`: 0 errors, 2 warnings (unused imports)
- `dart test`: 85 tests passing
- Architecture: CommandRunner + HAL for cross-platform development

---

## Suggestions

### Immediate

1. **Job Objects Implementation**: The current proxy relies on `inheritStdio`. For production, implement actual Windows Job Objects via FFI to guarantee zombie process cleanup.
2. **Remove Legacy Code**: Delete `utils/option_creator.dart`, `utils/symlink_creator.dart`, `utils/php_proxy.dart` as they are now superseded by the new architecture.

### Future Enhancements

1. **Auto-Detection**: Add `pvm detect` command to auto-detect PHP versions in common locations
2. **Version Download**: Add `pvm install <version>` to download PHP directly
3. **Plugin System**: Use CommandRunner's subcommand feature to allow third-party extensions
4. **Config File**: Add `pvm.yaml` for custom configurations (mirror directory, default versions)
