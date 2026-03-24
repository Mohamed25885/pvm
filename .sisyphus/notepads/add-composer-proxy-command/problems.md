# Technical Debt / Unresolved Problems

## 1. PhpCommand Refactor Pending
- **Description**: `lib/src/commands/php_command.dart` must be updated to accept `PhpExecutor` instead of `IProcessManager` and `IOSManager` separately.
- **Impact**: Without this, we cannot use the new service and the plan stalls.
- **Blocking**: ComposerCommand also needs PhpExecutor, so we must refactor first.

## 2. ComposerCommand Implementation Pending
- **Description**: Create `lib/src/commands/composer_command.dart` with PATH lookup for composer script.
- **Sub-problems**:
  - Need to implement `_findComposerScript()` that searches PATH for `composer`/`composer.phar` (Windows: `.bat/.cmd/.phar`; Unix: `composer`/`composer.phar`).
  - If batch file found, look for `composer.phar` in same directory.
  - Must use `_osManager.fileExists()` for all checks.
- **Tests needed**: `test/commands/composer_command_test.dart` covering found/not found, args forwarding, missing .pvm error.

## 3. pvm.dart Wiring Update Pending
- **Description**: After PhpCommand refactor, `pvm.dart` must instantiate `PhpExecutor` and pass it to both commands.
- **Current code**: Creates `processManager` and `osManager` separately, passes to commands.
- **New code**: `final phpExecutor = PhpExecutor(processManager, osManager);` then pass `phpExecutor` to `PhpCommand` and `ComposerCommand`.

## 4. Test Updates for PhpCommand
- **Description**: `test/commands/php_command_test.dart` currently uses mocks for `IProcessManager` and `IOSManager`. Must replace with `FakePhpExecutor` (or create a new fake for executor).
- **Option**: Could create `FakePhpExecutor` that extends `PhpExecutor` and overrides methods to capture calls, or create a test-specific subclass.

## 5. Manual QA Not Done
- Need to manually test `pvm composer` after implementation (but currently blocked by implementation).
- Need to verify error messages for missing `.pvm` and missing Composer.

## 6. README Update Pending
- Add section for `pvm composer` command with usage examples.
- Document that Composer must be installed globally (composer.phar in PATH).

## 7. Possible Gap: Environment in ProcessSpec
- We currently set `environment: Platform.environment`. This is correct but ensures the child process gets the full environment. However, note that `IOSManager` might have been expected to provide environment? It doesn't. We're okay.

## 8. Test Coverage Gaps
- ComposerCommand PATH lookup logic needs thorough tests for:
  - Windows: `composer.bat` finds `composer.phar` in same dir
  - Unix: `composer` or `composer.phar`
  - Composer not found → error
  - Batch file exists but `.phar` missing → treat as not found (skip batch)
  - Possibly test that `executable` in ProcessSpec is the PHP path (not composer path), and `arguments` start with composer script.

---

## Mitigation Plan

- Prioritize PhpCommand refactor next.
- Create `FakePhpExecutor` test double for PhpCommand tests.
- Then implement ComposerCommand.
- Then full test run.
- Then manual QA.

---
