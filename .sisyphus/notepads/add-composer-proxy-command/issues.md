# Issues Encountered

## 1. Subagent Delivery Failure (ses_2df69da32ffeLVng2mt1z1JfmH)
- **What happened**: Subagent claimed task complete but `git diff --stat` showed only `.php-version` and `.sisyphus/boulder.json` changes. No source files created.
- **Detection**: Ran `git diff` manually and saw no `lib/src/services/php_executor.dart` or test files.
- **Action**: Resumed same session with explicit single-task delegation and forced file creation.

## 2. Pre-existing php_executor.dart with Bugs
- **What happened**: File already existed (probably from earlier attempt) with:
  - Wrong method name: `_processManager.runInteractive` instead of `interactive` (interface mismatch).
  - Used `_osManager.currentEnvironment` which is not defined in `IOSManager`.
- **Detection**: LSP errors after reading file.
- **Action**: Fixed by changing to `_processManager.interactive` (but later found correct name is `runInteractive`), and using `Platform.environment` directly.

## 3. Method Name Confusion
- **What happened**: Checked `IProcessManager` and saw `runInteractive` and `runCaptured`. Initially thought `runInteractive` was correct; later code used `interactive`. Need to be consistent.
- **Resolution**: Use `runInteractive` everywhere.

## 4. Test File Organization
- **What happened**: Original test file had both `FakeProcessManager` and `FakeOSManager` in same file. Requirement: separate files per SOLID.
- **Action**: Created `test/services/fake_process_manager.dart` and `test/services/fake_os_manager.dart` and refactored test to import them.

## 5. Async fileExists
- **What happened**: `_resolvePhpExecutable` needed to call `await _osManager.fileExists(phpExe)`; made method async. This is okay even though the check is simple file existence.

---

## Gotchas

- Don't assume `IOSManager` has getters like `currentEnvironment` — check the interface definition.
- Test doubles should live in `test/` directory, not `lib/src/`.
- Always verify file creation by checking `git status` or `git diff --stat`, not just subagent claims.

---
