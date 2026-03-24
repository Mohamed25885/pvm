# Composer Proxy Implementation

## Status
In Progress

## Description
Implemented pvm composer command that runs Composer using the project's local PHP version (from `.pvm` symlink). The command searches the PATH for Composer (supports Windows batch files and `.phar`, Unix scripts) and forwards all arguments. Refactored PHP execution into a reusable `PhpExecutor` service.

## Phases

### Phase 1: Architecture & Service Extraction
- Status: Done
- Description: Created `PhpExecutor` to centralize PHP execution logic.
- Steps:
  1. Added `IOSManager.currentEnvironment` getter.
  2. Implemented `currentEnvironment` in `WindowsOSManager` and `MockOSManager`.
  3. Created `PhpExecutor` class with `runPhp` and `runScript` methods.
  4. Wrote unit tests for `PhpExecutor` (8 tests passing).

### Phase 2: ComposerCommand Implementation
- Status: Done
- Description: Built `ComposerCommand` with async PATH lookup and batch→phar resolution.
- Steps:
  1. Implemented `_findComposerScript` using `_osManager.currentEnvironment`.
  2. Implemented `_discoverRootPath` for project root discovery.
  3. Added test-friendly `runWithArgs` method.
  4. Registered command in `pvm.dart`.

### Phase 3: Testing & Fixes
- Status: In Progress
- Description: Fix remaining test failures and ensure full test suite passes.
- Steps:
  1. Updated `FakeOSManager` to include `currentEnvironment`.
  2. Fixed `ComposerCommand` to use `_osManager.currentEnvironment` instead of `Platform.environment`.
  3. Adjusted test paths to use Windows backslashes for local environment.
  4. 4/7 ComposerCommand tests currently passing; 3 failures need investigation.
  5. Run full `dart test` and fix any regressions.

### Phase 4: Documentation
- Status: To Do
- Description: Update README with `pvm composer` usage and examples.

### Phase 5: Manual QA
- Status: To Do
- Description: Verify end-to-end functionality with actual PHP project.
- Steps:
  1. Create temp project with `.pvm` local version.
  2. Run `pvm composer --version` and confirm Composer executes.
  3. Test with various arguments (e.g., `pvm composer install`, `pvm composer update`).
  4. Verify error handling when Composer not found.

### Phase 6: Commit
- Status: To Do
- Description: Commit all changes with proper message.

## Conclusion
- `pvm composer` fully implemented and mostly tested.
- `PhpExecutor` service enables future PHP-proxied commands.
- Remaining: fix 3 failing tests, full suite validation, documentation, QA.

## Suggestions
- Could extend PATH lookup to include common Composer install locations on Windows (e.g., `%APPDATA%\Composer\vendor\bin`) as fallback.
- Consider adding a `--composer` flag to override the Composer script path explicitly if needed.
- Extend test coverage for error handling when Composer script exists but is not executable.

## Progress Log

### 2026-03-24
- Completed architecture extraction and service implementation with 8 passing PhpExecutor tests.
- Implemented ComposerCommand with PATH-based script resolution and project root discovery.
- Fixed test infrastructure to use `currentEnvironment` instead of `Platform.environment`.
- Currently: 3 ComposerCommand tests failing; investigating root cause (likely test setup/assertion mismatch).
- Next: Diagnose test failures, run full test suite, update README, manual QA.
