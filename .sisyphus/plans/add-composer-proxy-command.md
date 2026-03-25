# Feature: Add `pvm composer` Proxy Command (with PhpExecutor service)

## Status
To Do

## Context
Composer (PHP dependency manager) requires the correct PHP version. Currently users must run `pvm php composer.phar ...` which is verbose. A `pvm composer` proxy would provide a seamless UX: `pvm composer install`, `pvm composer update`, etc., automatically using the project's local PHP version from `.pvm`.

Additionally, to avoid code duplication and improve maintainability, we will **extract a `PhpExecutor` service** that encapsulates PHP execution logic. Both `PhpCommand` and `ComposerCommand` will use this service, ensuring consistent behavior and a single source of truth for PHP resolution and process execution.

---

## Refactor: Extract `PhpExecutor` Service

### New Component
- `lib/src/services/php_executor.dart` — class `PhpExecutor`
  - Dependencies: `IProcessManager`, `IOSManager`
  - Methods:
    - `Future<int> runPhp(List<String> args, {String? workingDirectory})` — run `php` with args
    - `Future<int> runScript(String scriptPath, List<String> args, {String? workingDirectory})` — run a PHP script via local PHP
  - Private helper: `String _resolvePhpExecutable(String rootPath)` — returns absolute path to `.pvm/php.exe` (Windows) or `.pvm/php` (Unix). **Throws if missing** (no fallback).

### Refactor `PhpCommand`
- Update `PhpCommand` to take `PhpExecutor` in constructor (instead of `IProcessManager` directly)
- `run()` becomes: 
  ```dart
  final rootPath = _discoverRootPath(_osManager.currentDirectory);
  return _phpExecutor.runPhp(argResults!.rest, workingDirectory: rootPath);
  ```
- Remove duplicate PHP path resolution and process building logic from `PhpCommand`

---

## New ComposerCommand

### Implementation
- `lib/src/commands/composer_command.dart`
- Constructor: `ComposerCommand(this._phpExecutor, this._osManager)`
- `run()` steps:
  1. Discover `rootPath` using `_discoverRootPath(_osManager.currentDirectory)`
  2. **Find Composer script in PATH** (platform-aware):
     - Windows: search PATH for `composer.bat`, `composer.cmd`, `composer.phar`
     - Unix: search PATH for `composer`, `composer.phar`
     - When batch file found, look for `composer.phar` in same directory (Composer-Setup layout)
  3. If not found: print error and return 1
  4. Call `_phpExecutor.runScript(composerScript, argResults!.rest, workingDirectory: rootPath)`
  5. Return exit code

### Behavior
- **Always uses local PHP** (from `.pvm`) to run the Composer script
- Forwards all arguments unchanged
- Working directory set to project root
- Exit code passthrough
- Clear error messages when Composer not found or local version missing

---

## Objectives

### Core Objective
1. Extract `PhpExecutor` service to centralize PHP execution
2. Refactor `PhpCommand` to use `PhpExecutor`
3. Build `ComposerCommand` on top of `PhpExecutor` with PATH-based Composer resolution

### Deliverables
- `lib/src/services/php_executor.dart` (new)
- Modified `lib/src/commands/php_command.dart` (refactor)
- `lib/src/commands/composer_command.dart` (new)
- Update `pvm.dart` to wire `PhpExecutor` and register both commands
- Tests:
  - `test/services/php_executor_test.dart` (new)
  - Update `test/commands/php_command_test.dart` (mock new service)
  - `test/commands/composer_command_test.dart` (new)
- Documentation: update `README.md` with `pvm composer` section and usage examples

### Definition of Done
- [ ] `dart analyze` clean
- [ ] All tests pass (including new and updated)
- [ ] `pvm php -v` still works (unchanged behavior)
- [ ] `pvm composer --version` works and shows Composer version
- [ ] `pvm composer install` runs in project with local PHP
- [ ] Exit codes preserved
- [ ] Arguments forwarded
- [ ] Errors handled gracefully: missing `.pvm`, missing Composer in PATH
- [ ] No regression in existing commands

### Must Have
- `PhpExecutor` abstracts PHP execution (interactive via `IProcessManager`)
- `PhpExecutor.runScript()` runs any PHP script with local PHP
- `PhpExecutor` uses `_osManager.fileExists()` for checks (no direct `File` calls)
- `PhpExecutor._resolvePhpExecutable()` throws if `.pvm/php` missing (no fallback to system PHP)
- `ComposerCommand` finds Composer script in PATH (Windows: `.bat/.cmd/.phar`; Unix: `composer`/`composer.phar`)
- When Composer found as batch file, locate `composer.phar` in same directory (Composer-Setup layout)
- `ComposerCommand` uses `PhpExecutor.runScript()`
- Both commands use same rootPath discovery logic (DRY)

### Must NOT Have
- No fallback to system `php` if `.pvm` missing — always require local version
- No direct `File(...).existsSync()` — always use `_osManager.fileExists()`
- No assumption that `composer.phar` is in project root — must search PATH
- No modification to `global` or `list` commands
- No new package dependencies
- No removal or breaking change to existing `pvm php` behavior

---

## Execution Strategy

### Wave 1: Service Layer
1. Create `lib/src/services/php_executor.dart` with `PhpExecutor` class
2. Write unit tests: `test/services/php_executor_test.dart` (mock dependencies)
   - Test: `runPhp()` builds correct `ProcessSpec` with local PHP and args
   - Test: `runScript()` builds correct spec with script as first arg
   - Test: `_resolvePhpExecutable()` returns correct path; throws when missing
3. Verify `dart analyze`

### Wave 2: Refactor PhpCommand
4. Modify `lib/src/commands/php_command.dart` to depend on `PhpExecutor`
   - Constructor: `PhpCommand(this._phpExecutor, this._osManager)`
   - `run()`: discover rootPath, then `return _phpExecutor.runPhp(argResults!.rest, workingDirectory: rootPath);`
5. Remove old process-building code from `PhpCommand`
6. Update tests (`test/commands/php_command_test.dart`) to inject fake `PhpExecutor`
   - Replace `MockProcessManager` with `FakePhpExecutor` that records calls
7. Run tests — ensure no regressions

### Wave 3: ComposerCommand
8. Create `lib/src/commands/composer_command.dart`
9. Implement PATH lookup for Composer in `ComposerCommand`:
   ```dart
   String? _findComposerScript() {
     final pathEnv = _osManager.currentEnvironment['PATH'] ?? '';
     final separator = Platform.isWindows ? ';' : ':';
     final dirs = pathEnv.split(separator);
     final candidates = Platform.isWindows 
       ? ['composer.bat', 'composer.cmd', 'composer.phar']
       : ['composer', 'composer.phar'];
     for (final dir in dirs) {
       for (final name in candidates) {
         final candidate = p.join(dir, name);
         if (_osManager.fileExists(candidate)) {
           if (candidate.endsWith('.bat') || candidate.endsWith('.cmd')) {
             // Batch file: look for composer.phar in same directory
             final phar = p.join(dir, 'composer.phar');
             if (_osManager.fileExists(phar)) return phar;
           } else {
             return candidate;
           }
         }
       }
     }
     return null;
   }
   ```
10. In `run()`: call `_findComposerScript()`; if null, error; else `_phpExecutor.runScript(composerScript, argResults!.rest, workingDirectory: rootPath)`
11. Write tests: `test/commands/composer_command_test.dart`
    - Test: Composer found → `runScript` called with correct script and args
    - Test: Composer not found → exit 1, error message
    - Test: No local `.pvm` → exit 1, error message
    - Test: Arguments forwarded unchanged
    - Test: Batch file resolution finds `composer.phar` in same dir
12. Add command to `pvm.dart`:
    - Create `PhpExecutor` instance: `final phpExecutor = PhpExecutor(processManager, osManager);`
    - Register: `runner.addCommand(PhpCommand(phpExecutor, osManager));`
    - Register: `runner.addCommand(ComposerCommand(phpExecutor, osManager));`

### Wave 4: Documentation & QA
13. Update `README.md` — add `pvm composer` section, examples, prerequisites
    - Example: `pvm composer install`, `pvm composer update --lock`
    - Note: requires Composer installed globally (composer.phar in PATH)
14. Manual QA: test `pvm composer --version` in test environment with a dummy composer.phar
15. Manual QA: test `pvm composer install` simulation (composer.phar that prints "running")
16. Manual QA: verify error when `.pvm` missing (delete `.pvm`, run `pvm composer` → error)
17. Manual QA: verify error when Composer not in PATH (rename, run → error)
18. Final `dart test` and `dart analyze`
19. Commit: `feat(pvm): add composer proxy via PhpExecutor service; refactor PhpCommand`

---

## TODO Breakdown

- [x] 1. Create `lib/src/services/php_executor.dart` (service interface + implementation)
- [x] 2. Write `test/services/php_executor_test.dart` (happy path, missing PHP, error propagation)
- [x] 3. Refactor `lib/src/commands/php_command.dart` to use `PhpExecutor`
- [x] 4. Update `test/commands/php_command_test.dart` to use fake `PhpExecutor`
- [x] 5. Verify `dart analyze` and `dart test` (all pass)
- [x] 6. Create `lib/src/commands/composer_command.dart`
- [x] 7. Implement PATH lookup for Composer in `ComposerCommand`
- [x] 8. Write `test/commands/composer_command_test.dart` (Composer found/not found, args forward, no local .pvm error)
- [x] 9. Update `pvm.dart` to instantiate `PhpExecutor` and inject into both commands
- [x] 10. Run full test suite (`dart test`) and `dart analyze` — ensure clean
- [x] 11. Update `README.md` with Composer section
- [x] 12. Manual QA: `pvm composer --version` in test environment
- [x] 13. Manual QA: `pvm composer install` simulation
- [ ] 14. Commit changes

---

## Acceptance Criteria (Agent-Verifiable)

### PhpExecutor tests
- [x] `php_executor_test.dart` verifies `runPhp()` builds correct `ProcessSpec` with local PHP and args
- [x] `php_executor_test.dart` verifies `runScript()` builds correct spec with script as first arg
- [x] `php_executor_test.dart` verifies `_resolvePhpExecutable()` returns correct path and throws when missing

### ComposerCommand tests
- [ ] `composer_command_test.dart` verifies successful run when Composer found in PATH and `.pvm` exists
- [ ] `composer_command_test.dart` verifies error when Composer not found (exit 1, message)
- [ ] `composer_command_test.dart` verifies error when `.pvm` missing (exit 1, message)
- [ ] `composer_command_test.dart` verifies all args forwarded unchanged
- [ ] `composer_command_test.dart` verifies correct script path resolution (batch → .phar)

### Integration
- [ ] Existing `php_command_test.dart` still passes with refactored `PhpCommand`
- [ ] `dart test` total tests >= previous count
- [ ] `dart analyze` passes with 0 issues

### Manual QA
- [ ] Run: `pvm composer --version` prints Composer version (composer.phar must be in PATH)
- [ ] Run: `pvm composer install` (simulate with a dummy composer.phar that prints something)
- [ ] Verify error when `.pvm` missing (delete `.pvm`, run `pvm composer` → error)
- [ ] Verify error when Composer not in PATH (rename composer in PATH, run → error)

---

## Technical Notes

### PATH lookup helper
We'll implement `_findComposerScript()` inside `ComposerCommand` using `_osManager.currentEnvironment['PATH']` and `_osManager.fileExists()`.

### Composer resolution algorithm
See implementation in Wave 3 step 9. Key: prefer `.phar`; if batch file found, look for `composer.phar` in same directory. Do **not** execute batch directly (would use system PHP).

### Error messages
- Missing `.pvm`: `Error: No local PHP version set. Run "pvm use <version>" first.`
- Composer not found: `Error: Composer not found in PATH. Install Composer globally or ensure composer.phar is in your PATH.`

### No fallback policy
`PhpExecutor._resolvePhpExecutable()` **must throw** if `.pvm/php` does not exist. This ensures we never accidentally use system PHP. The calling command catches and prints user-friendly error.

---

## Dependencies
- None new (uses existing `IProcessManager`, `IOSManager`, `package:path` already in project)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| PATH lookup platform differences | Implement and test on Windows and WSL; use `Platform.isWindows` |
| Composer found as `.bat` without `.phar` | Skip batch file if `.phar` not present (avoid using system PHP) |
| Slow PATH lookup | Acceptable overhead; cache if needed later |
| Breaking `pvm php` during refactor | Extensive tests for `PhpExecutor` and `PhpCommand` before adding `ComposerCommand` |

---

## Workflow

1. **Service first** — create `PhpExecutor` and tests (prove it works)
2. **Refactor** — update `PhpCommand` to use service; verify no regressions
3. **Composer** — implement `ComposerCommand` on top of service
4. **Wiring** — update `pvm.dart`
5. **Docs** — update README
6. **QA** — manual checks

---

## Success Criteria

- `pvm php -v` works exactly as before
- `pvm composer -v` prints Composer version using local PHP
- `pvm composer install` executes Composer with local PHP
- All tests pass; analyzer clean
- No fallback to system PHP when `.pvm` missing (clear error instead)

---

**Implementation will follow this plan after approval.**
