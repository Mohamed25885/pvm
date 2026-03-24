# Refactor PHP Process Execution Abstraction

**Status: COMPLETE** — Approved 2026-03-24

## TL;DR
> **Summary**: Replace the Windows-centric `ManagedProcessRunner` path with a small cross-platform process abstraction that keeps explicit PHP executable resolution in `PhpCommand`, defaults to interactive terminal behavior, and exposes a separate captured-output path for tests and future internal use.
> **Deliverables**:
> - New process contract centered on `ProcessSpec` + explicit interactive/captured execution
> - `PhpCommand` and `PvmCommandRunner` rewired to depend on the abstraction instead of `ManagedProcessRunner`
> - Cross-platform `dart:io` implementation with Windows cleanup explicitly deferred
> - TDD coverage for interactive default behavior, captured mode, exit-code passthrough, and failure paths
> **Effort**: Medium
> **Parallel**: YES - 2 waves
> **Critical Path**: 1 → 2 → 3/4 → 5 → 6/7/8

## Context
### Original Request
The user is not happy with `ManagedProcessRunner.dart` because it is tightly coupled to Windows and its output piping makes interactive PHP commands difficult to control, especially commands that require prompt confirmation such as production migrations. The user cited FVM as a better reference for process abstraction and cross-platform maintainability.

### Interview Summary
- Current `pvm php` behavior is controlled by `PhpCommand` plus a concrete `ManagedProcessRunner` wired in `pvm.dart`.
- The refactor must default `pvm php ...` to interactive terminal behavior.
- The refactor must target true cross-platform runtime where feasible.
- The refactor must keep explicit PHP executable resolution rather than switch to PATH injection.
- Windows Job Object cleanup must be removed from the first refactor instead of being partially preserved.
- Testing strategy is TDD.

### Metis Review (gaps addressed)
- Locked phase-1 scope to behavior-preserving process refactor only; no symlink/global/use/list redesign.
- Preserved explicit PHP path resolution in `PhpCommand` rather than moving resolution into the process layer.
- Defined cross-platform scope for this plan as: the new core process service and its tests must compile and run without Windows-only APIs; full non-Windows parity for all PVM features is not required.
- Added explicit acceptance criteria for interactive behavior, captured behavior, exit-code passthrough, and deferred cleanup semantics.
- Deferred parent-exit process-tree cleanup redesign to later scope instead of encoding a misleading public cleanup API.

## Work Objectives
### Core Objective
Refactor the PHP execution path so that `pvm php ...` uses a minimal, testable, cross-platform process abstraction with separate interactive and captured execution paths, while preserving current explicit PHP path resolution and child exit-code passthrough.

### Deliverables
- `lib/src/core/process_manager.dart` defining the new shared process contract
- `lib/src/process/io_process_manager.dart` implementing the cross-platform runtime using `dart:io`
- Updated `lib/src/commands/php_command.dart` and `pvm.dart` wired to the abstraction
- Updated test doubles and targeted tests for command/process behavior
- Removal of `ManagedProcessRunner` and Windows Job Object code from the default runtime path

### Definition of Done (verifiable conditions with commands)
- `dart analyze`
- `dart test test/commands/php_command_test.dart`
- `dart test test/process/io_process_manager_test.dart`
- `dart test test/adversarial_test.dart`
- `dart test`

### Must Have
- `PhpCommand` owns PHP executable resolution and passes an explicit executable path into the process abstraction
- Public process API exposes two explicit behaviors: interactive execution and captured execution
- Interactive execution is the default for `pvm php ...`
- Captured execution returns stdout, stderr, and exit code separately for tests/internal use
- `PhpCommand` returns the child exit code unchanged
- Core process implementation uses only cross-platform `dart:io` APIs
- TDD workflow: characterization tests first, then refactor, then regression coverage

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- No PATH injection architecture
- No Windows Job Object, `taskkill`, or public kill-tree API in the new core path
- No retention of the old `runPhp` / `startProcess` / `killProcessTree` interface shape
- No symlink/global/use/list feature changes except compile-safe dependency rewiring
- No mixing explicit PHP path resolution into the generic process manager
- No hidden Windows-only imports in the shared process contract or default implementation

## Verification Strategy
> ZERO HUMAN INTERVENTION — all verification is agent-executed.
- Test decision: TDD with `package:test`
- QA policy: Every task includes agent-executed scenarios using targeted `dart test`/`dart analyze` commands
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.txt`

## Execution Strategy
### Parallel Execution Waves
> Target: 5-8 tasks per wave. <3 per wave (except final) = under-splitting.
> Extract shared dependencies as Wave-1 tasks for max parallelism.

Wave 1: 1) characterization tests, 2) new process contract, 3) interactive runner, 4) captured runner, 5) command/runtime wiring

Wave 2: 6) remove legacy Windows runner path, 7) regression and edge-case tests, 8) finalize public imports/mocks/docs for deferred cleanup contract

### Dependency Matrix (full, all tasks)
| Task | Depends On | Blocks |
|---|---|---|
| 1 | none | 2, 5, 7 |
| 2 | 1 | 3, 4, 5, 8 |
| 3 | 2 | 5, 7 |
| 4 | 2 | 7 |
| 5 | 1, 2, 3 | 6, 7, 8 |
| 6 | 5 | 8 |
| 7 | 1, 3, 4, 5 | Final Verification |
| 8 | 2, 5, 6 | Final Verification |

### Agent Dispatch Summary (wave → task count → categories)
- Wave 1 → 5 tasks → `quick` for file-scoped tests/contracts, `unspecified-high` for wiring/runtime refactor
- Wave 2 → 3 tasks → `unspecified-high` for legacy removal and regression hardening, `quick` for import/mock cleanup

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

- [x] 1. Characterize current `PhpCommand` process behavior before rewiring dependencies

  **What to do**: Add a focused `test/commands/php_command_test.dart` that locks the current command boundary behavior before any refactor. Cover: resolved executable path ownership in `PhpCommand`, unchanged argument forwarding, child exit-code passthrough, and failure handling when `.pvm` or the PHP executable is missing. Keep tests mock-driven; do not spawn real PHP.
  **Must NOT do**: Do not refactor production process code in this task. Do not add PATH-injection behavior. Do not let tests depend on Windows-only process cleanup semantics.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: test-only, file-scoped characterization work
  - Skills: `[]` — no specialized skill required
  - Omitted: `[git-master]` — no history or git workflow needed

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 2, 5, 7 | Blocked By: none

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `lib/src/commands/php_command.dart:14-49` — current command owns local path lookup, PHP executable resolution, and runner delegation
  - Pattern: `pvm.dart:25-39` — current runtime wiring constructs the concrete runner in the command runner
  - Pattern: `lib/src/managers/mock_os_manager.dart:144-216` — existing `MockProcessManager` seam to evolve for injected process tests
  - Test: `test/adversarial_test.dart:210-264` — existing PHP command edge-case coverage style
  - Test: `test/mock_test.dart:61-100` — existing interface-level process mock testing style

  **Acceptance Criteria** (agent-executable only):
  - [ ] `dart test test/commands/php_command_test.dart`
  - [ ] `dart test test/commands/php_command_test.dart --name "php command forwards resolved executable and args unchanged"`
  - [ ] `dart test test/commands/php_command_test.dart --name "php command returns child exit code unchanged"`
  - [ ] `dart test test/commands/php_command_test.dart --name "php command returns 1 when resolved php executable is missing"`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```
  Scenario: Happy path boundary characterization
    Tool: Bash
    Steps:
      1. Run `dart test test/commands/php_command_test.dart --name "php command forwards resolved executable and args unchanged"`
      2. Run `dart test test/commands/php_command_test.dart --name "php command returns child exit code unchanged"`
    Expected: Both tests pass with exit code 0 and no real process spawn.
    Evidence: .sisyphus/evidence/task-1-php-command-characterization.txt

  Scenario: Failure path characterization
    Tool: Bash
    Steps:
      1. Run `dart test test/commands/php_command_test.dart --name "php command returns 1 when resolved php executable is missing"`
      2. Run `dart test test/commands/php_command_test.dart --name "php command returns 1 when local version directory is missing"`
    Expected: Both tests pass with exit code 0 and assert command-level failure handling.
    Evidence: .sisyphus/evidence/task-1-php-command-characterization-error.txt
  ```

  **Commit**: NO | Message: `test(process): add php command characterization coverage` | Files: `test/commands/php_command_test.dart`

- [x] 2. Replace the Windows-internal process contract with a use-case process API

  **What to do**: Introduce `lib/src/core/process_manager.dart` with an immutable `ProcessSpec`, an immutable captured-result type, and an `IProcessManager` contract exposing two explicit operations: interactive execution and captured execution. Remove the old `runPhp` / `startProcess` / `killProcessTree` shape from the public contract, and update the mock process manager to match the new API without adding Windows cleanup promises.
  **Must NOT do**: Do not leave both old and new process interfaces alive. Do not add PATH resolution, OS cleanup hooks, or command-specific PHP logic to the contract.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: contract redesign affecting multiple production and test files
  - Skills: `[]` — no specialized skill required
  - Omitted: `[git-master]` — no history or git workflow needed

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 3, 4, 5, 8 | Blocked By: 1

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `lib/src/core/os_manager.dart:13-18` — old `IProcessManager` shape that must be replaced, not preserved
  - Pattern: `lib/src/managers/mock_os_manager.dart:144-216` — current mock process manager to migrate to the new contract
  - Pattern: `pvm.dart:25-39` — runtime wiring that will later inject the new contract
  - External: `https://github.com/leoafarias/fvm/blob/main/lib/src/services/process_service.dart` — reference for splitting interactive and captured execution semantics
  - External: `https://github.com/leoafarias/fvm/blob/main/lib/src/services/base_service.dart` — reference for keeping process concerns outside command logic

  **Acceptance Criteria** (agent-executable only):
  - [ ] `dart analyze`
  - [ ] `dart test test/mock_test.dart`
  - [ ] Workspace search for `runPhp|startProcess|killProcessTree` returns no production interface declarations under `lib/src/core/`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```
  Scenario: New contract compiles and mocks align
    Tool: Bash
    Steps:
      1. Run `dart analyze`
      2. Run `dart test test/mock_test.dart`
    Expected: Analyzer and mock tests pass with exit code 0.
    Evidence: .sisyphus/evidence/task-2-process-contract.txt

  Scenario: Legacy API shape removed from public core contract
    Tool: Grep
    Steps:
      1. Search `D:\Codes\Algorithm\pvm\lib\src\core` for `runPhp|startProcess|killProcessTree`
      2. Confirm only the new interactive/captured API remains in core process declarations
    Expected: No matches for legacy process method names in the core process contract.
    Evidence: .sisyphus/evidence/task-2-process-contract-error.txt
  ```

  **Commit**: NO | Message: `refactor(process): define use-case driven process contract` | Files: `lib/src/core/process_manager.dart`, `lib/src/core/os_manager.dart`, `lib/src/managers/mock_os_manager.dart`, `test/mock_test.dart`

- [x] 3. Implement the interactive process path as the default cross-platform runtime

  **What to do**: Create `lib/src/process/io_process_manager.dart` as the default `dart:io` implementation of the new process contract. Implement the interactive execution path so it preserves terminal-capable behavior for commands like production migration confirmation, inherits environment/current working directory, and returns the child exit code unchanged. Keep any platform-specific behavior private and best-effort; do not expose cleanup/tree-kill APIs.
  **Must NOT do**: Do not import `win32`, `taskkill`, Job Object code, or `ManagedProcessRunner`. Do not promise parent-exit child-tree cleanup. Do not parse command output in the process manager.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: core runtime implementation with cross-platform behavior constraints
  - Skills: `[]` — no specialized skill required
  - Omitted: `[git-master]` — no history or git workflow needed

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 5, 7 | Blocked By: 2

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `lib/src/process/managed_process_runner.dart:14-49` — current spawn/wait lifecycle to preserve at the behavior level, not the implementation level
  - Anti-pattern: `lib/src/process/managed_process_runner.dart:75-88` — Windows-only signal/taskkill behavior that must not remain in the shared core path
  - Pattern: `lib/src/commands/php_command.dart:26-47` — command expects a child exit code result and command-level error handling
  - External: `https://github.com/leoafarias/fvm/blob/main/lib/src/services/process_service.dart` — reference for distinct interactive process execution behavior

  **Acceptance Criteria** (agent-executable only):
  - [ ] `dart test test/process/io_process_manager_test.dart --name "interactive execution preserves exit code"`
  - [ ] `dart test test/process/io_process_manager_test.dart --name "interactive execution preserves working directory and environment"`
  - [ ] `dart analyze`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```
  Scenario: Interactive runtime happy path
    Tool: Bash
    Steps:
      1. Run `dart test test/process/io_process_manager_test.dart --name "interactive execution preserves exit code"`
      2. Run `dart test test/process/io_process_manager_test.dart --name "interactive execution preserves working directory and environment"`
    Expected: Both tests pass with exit code 0 and prove the cross-platform interactive path works without Windows-only APIs.
    Evidence: .sisyphus/evidence/task-3-interactive-process.txt

  Scenario: Interactive runtime avoids legacy Windows-only coupling
    Tool: Grep
    Steps:
      1. Search `D:\Codes\Algorithm\pvm\lib\src\process\io_process_manager.dart` for `taskkill|JobObject|ManagedProcessRunner|win32`
      2. Confirm no legacy Windows cleanup symbols are present
    Expected: No matches for legacy Windows-only runtime coupling in the new default process implementation.
    Evidence: .sisyphus/evidence/task-3-interactive-process-error.txt
  ```

  **Commit**: NO | Message: `feat(process): add interactive io process manager` | Files: `lib/src/process/io_process_manager.dart`, `test/process/io_process_manager_test.dart`

- [x] 4. Add a captured execution path for tests and future internal consumers

  **What to do**: Complete the captured execution behavior in `lib/src/process/io_process_manager.dart` so the process manager can return stdout, stderr, and exit code without terminal inheritance. Use this to support deterministic tests and future non-interactive consumers, but keep `PhpCommand` on the interactive path by default.
  **Must NOT do**: Do not change `PhpCommand` to use captured mode by default. Do not merge interactive and captured behavior into one flag-heavy public API. Do not add output parsing rules specific to PHP commands.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: shared runtime behavior plus result-shape correctness
  - Skills: `[]` — no specialized skill required
  - Omitted: `[git-master]` — no history or git workflow needed

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 7 | Blocked By: 2

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `lib/src/process/managed_process_runner.dart:31-34` — current stdout/stderr forwarding behavior that should not define captured-mode design
  - Pattern: `lib/src/commands/php_command.dart:41-47` — command-level error handling should stay outside captured result aggregation
  - External: `https://github.com/leoafarias/fvm/blob/main/lib/src/services/process_service.dart` — reference for a dedicated captured-output execution path

  **Acceptance Criteria** (agent-executable only):
  - [ ] `dart test test/process/io_process_manager_test.dart --name "captured execution returns stdout stderr and exit code separately"`
  - [ ] `dart test test/process/io_process_manager_test.dart --name "captured execution does not require terminal inheritance"`
  - [ ] `dart analyze`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```
  Scenario: Captured mode happy path
    Tool: Bash
    Steps:
      1. Run `dart test test/process/io_process_manager_test.dart --name "captured execution returns stdout stderr and exit code separately"`
      2. Run `dart test test/process/io_process_manager_test.dart --name "captured execution does not require terminal inheritance"`
    Expected: Both tests pass with exit code 0 and prove captured mode is deterministic and separate from interactive mode.
    Evidence: .sisyphus/evidence/task-4-captured-process.txt

  Scenario: Captured mode failure path
    Tool: Bash
    Steps:
      1. Run `dart test test/process/io_process_manager_test.dart --name "captured execution preserves non-zero exit code"`
      2. Run `dart test test/process/io_process_manager_test.dart --name "captured execution reports process start failure clearly"`
    Expected: Both tests pass with exit code 0 and assert explicit failure-path behavior.
    Evidence: .sisyphus/evidence/task-4-captured-process-error.txt
  ```

  **Commit**: NO | Message: `feat(process): add captured io process execution` | Files: `lib/src/process/io_process_manager.dart`, `test/process/io_process_manager_test.dart`

- [x] 5. Rewire `PhpCommand` and `PvmCommandRunner` to the new process abstraction

  **What to do**: Update `PhpCommand` so it depends on the new `IProcessManager` contract and calls the interactive execution path by default after resolving the explicit PHP executable. Update `PvmCommandRunner` to construct and inject the new default implementation. Preserve current CLI ownership boundaries: `PhpCommand` resolves the executable, builds the process spec, forwards args unchanged, preserves current working directory/environment, and returns the child exit code unchanged.
  **Must NOT do**: Do not move PHP path resolution into the process manager. Do not introduce PATH injection. Do not leave `PhpCommand` importing `ManagedProcessRunner` or any Windows-only runtime helpers.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: dependency inversion across entrypoint and command wiring
  - Skills: `[]` — no specialized skill required
  - Omitted: `[git-master]` — no history or git workflow needed

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 6, 7, 8 | Blocked By: 1, 2, 3

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `lib/src/commands/php_command.dart:14-49` — current command constructor and run path to replace with interface-driven wiring
  - Pattern: `pvm.dart:25-39` — current runner field and dependency construction to replace
  - Pattern: `lib/src/core/os_manager.dart:13-18` — legacy process interface location to decouple from command wiring
  - Test: `test/commands/php_command_test.dart` — characterization tests created in Task 1 must stay green
  - Test: `test/adversarial_test.dart:197-264` — existing php command edge cases that must continue to pass

  **Acceptance Criteria** (agent-executable only):
  - [ ] `dart test test/commands/php_command_test.dart`
  - [ ] `dart test test/adversarial_test.dart --name "php command with extra arguments passes them"`
  - [ ] Workspace search for `ManagedProcessRunner` returns no matches in `lib/src/commands/php_command.dart` or `pvm.dart`
  - [ ] `dart analyze`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```
  Scenario: Interactive path becomes the command default
    Tool: Bash
    Steps:
      1. Run `dart test test/commands/php_command_test.dart --name "php command uses interactive process execution by default"`
      2. Run `dart test test/commands/php_command_test.dart --name "php command forwards resolved executable and args unchanged"`
    Expected: Both tests pass with exit code 0 and prove default interactive routing plus explicit executable ownership.
    Evidence: .sisyphus/evidence/task-5-php-wiring.txt

  Scenario: Command failure behavior remains stable
    Tool: Bash
    Steps:
      1. Run `dart test test/commands/php_command_test.dart --name "php command returns child exit code unchanged"`
      2. Run `dart test test/adversarial_test.dart --name "php command with no local .pvm directory"`
    Expected: Both tests pass with exit code 0 and verify stable failure handling after dependency inversion.
    Evidence: .sisyphus/evidence/task-5-php-wiring-error.txt
  ```

  **Commit**: NO | Message: `refactor(php): inject process manager abstraction` | Files: `lib/src/commands/php_command.dart`, `pvm.dart`, related imports/tests`

- [x] 6. Remove the legacy Windows-only runner stack from the default runtime path

  **What to do**: Delete or fully retire the `ManagedProcessRunner` + Job Object path from production wiring once Task 5 is green. Remove unused imports/exports and any dead runtime code tied to `ManagedProcessRunner`, `job_object_manager.dart`, `ffi_bindings.dart`, and `job_object_constants.dart` if nothing in production uses them. Update `lib/src/process/process.dart` accordingly.
  **Must NOT do**: Do not keep dead code around “just in case” if production references are gone. Do not leave Windows-only cleanup symbols exported from the default process barrel. Do not silently preserve a partial cleanup promise.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: dead-code removal across runtime and exports with analyzer safety requirements
  - Skills: `[]` — no specialized skill required
  - Omitted: `[git-master]` — no history or git workflow needed

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 8 | Blocked By: 5

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `lib/src/process/managed_process_runner.dart:1-108` — legacy implementation to remove from the default runtime path
  - Pattern: `lib/src/process/job_object_manager.dart:1-101` — Windows-only cleanup layer to retire from phase 1
  - Pattern: `lib/src/process/ffi_bindings.dart:1-84` — FFI bindings only justified by the retired Job Object path
  - Pattern: `lib/src/process/process.dart:1-4` — barrel file that must stop exporting removed/default-retired components
  - Pattern: `pvm.dart:27-33` — previous concrete runner wiring that should already be gone after Task 5

  **Acceptance Criteria** (agent-executable only):
  - [ ] `dart analyze`
  - [ ] Workspace search for `ManagedProcessRunner|JobObjectManager|taskkill|AssignProcessToJobObject` returns no production matches under `lib/src/`
  - [ ] `dart test test/commands/php_command_test.dart`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```
  Scenario: Legacy runtime path removed cleanly
    Tool: Grep
    Steps:
      1. Search `D:\Codes\Algorithm\pvm\lib\src` for `ManagedProcessRunner|JobObjectManager|taskkill|AssignProcessToJobObject`
      2. Confirm no production matches remain after the refactor
    Expected: No matches remain in production runtime code.
    Evidence: .sisyphus/evidence/task-6-legacy-runtime-removal.txt

  Scenario: Removal does not break command execution tests
    Tool: Bash
    Steps:
      1. Run `dart analyze`
      2. Run `dart test test/commands/php_command_test.dart`
    Expected: Analyzer and targeted command tests pass with exit code 0 after legacy code removal.
    Evidence: .sisyphus/evidence/task-6-legacy-runtime-removal-error.txt
  ```

  **Commit**: NO | Message: `refactor(process): remove legacy managed runner path` | Files: `lib/src/process/process.dart`, removed legacy runtime files, updated imports/tests`

- [x] 7. Add regression coverage for interaction, exit-code, and cross-platform edge cases

  **What to do**: Expand targeted test coverage around the new abstraction and `PhpCommand` wiring. Cover executable paths with spaces, non-zero child exit codes, process start failures, heavy stdout/stderr separation in captured mode, and command behavior that requires interactive terminal semantics. Keep tests deterministic and mock/fake driven; no manual prompt confirmation steps.
  **Must NOT do**: Do not reintroduce Windows-only cleanup assertions. Do not rely on a real PHP installation. Do not treat PATH lookup as part of the test matrix.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: mostly test additions and focused regression coverage
  - Skills: `[]` — no specialized skill required
  - Omitted: `[git-master]` — no history or git workflow needed

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: Final Verification | Blocked By: 1, 3, 4, 5

  **References** (executor has NO interview context — be exhaustive):
  - Test: `test/adversarial_test.dart:197-264` — existing php command path/argument edge cases to preserve and tighten
  - Test: `test/adversarial_test.dart:401-440` — existing invalid path coverage style for unusual paths
  - Pattern: `lib/src/commands/php_command.dart:27-47` — command-level success/failure expectations
  - Pattern: `lib/src/process/io_process_manager.dart` — new runtime under test for interactive/captured behavior

  **Acceptance Criteria** (agent-executable only):
  - [ ] `dart test test/process/io_process_manager_test.dart`
  - [ ] `dart test test/commands/php_command_test.dart`
  - [ ] `dart test test/adversarial_test.dart --name "php command with path containing spaces"`
  - [ ] `dart test test/adversarial_test.dart --name "php command with very long argument"`

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```
  Scenario: Edge-case happy path regression suite
    Tool: Bash
    Steps:
      1. Run `dart test test/process/io_process_manager_test.dart`
      2. Run `dart test test/commands/php_command_test.dart`
    Expected: Both suites pass with exit code 0 and verify interactive/captured behavior remains deterministic.
    Evidence: .sisyphus/evidence/task-7-process-regressions.txt

  Scenario: Edge-case failure-path regression suite
    Tool: Bash
    Steps:
      1. Run `dart test test/adversarial_test.dart --name "php command with path containing spaces"`
      2. Run `dart test test/adversarial_test.dart --name "php command with very long argument"`
      3. Run `dart test test/process/io_process_manager_test.dart --name "captured execution reports process start failure clearly"`
    Expected: All targeted tests pass with exit code 0 and assert the intended edge-case behavior without Windows-only cleanup assumptions.
    Evidence: .sisyphus/evidence/task-7-process-regressions-error.txt
  ```

  **Commit**: NO | Message: `test(process): add regression coverage for interactive and captured flows` | Files: `test/process/io_process_manager_test.dart`, `test/commands/php_command_test.dart`, `test/adversarial_test.dart`

- [x] 8. Normalize public imports, mocks, and deferred-cleanup documentation around the new contract

- [ ] 9. Introduce a minimal per-project settings hook (to pave the way for .php-version driven defaults) and capture its interface in the plan
- [ ] 10. Wire DI in UseCommand to inject a SettingsService and prepare to read .php-version for defaults
- [ ] 11. Add tests for new per-project settings flow (no env vars; CLI flags override) and ensure no breakage to existing tests
- [ ] 12. Add plan for a root-level .php-version migration note: alignment with plan docs and evidence tracking
- [ ] 13. Remove any remaining references to deprecated forceUsingVersion or similar knobs in tests and docs
  **What to do**: Finish the refactor by removing stale references to the old process API from supporting files, keeping the public import surface coherent, and documenting the new non-goal clearly in code/tests: phase 1 does not guarantee parent-exit process-tree cleanup. Ensure all mocks/fakes/tests use `ProcessSpec` and the new result types consistently.
  **Must NOT do**: Do not add a new cleanup mechanism in this task. Do not leave comments or tests implying that tree cleanup is still guaranteed. Do not keep mixed old/new process terminology in public code.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: cleanup and consistency work across support files
  - Skills: `[]` — no specialized skill required
  - Omitted: `[git-master]` — no history or git workflow needed

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: Final Verification | Blocked By: 2, 5, 6

  **References** (executor has NO interview context — be exhaustive):
  - Pattern: `lib/src/process/process.dart:1-4` — current barrel export surface to normalize
  - Pattern: `lib/src/managers/mock_os_manager.dart:144-216` — current mock terminology and signatures to keep consistent with the new contract
  - Test: `test/mock_test.dart:61-100` — existing interface-level test expectations to update
  - Metis guardrail: deferred cleanup must be explicit and test-visible, not an undocumented regression
  - Oracle guardrail: do not preserve `runPhp` / `startProcess` / `killProcessTree` naming alongside the new contract

  **Acceptance Criteria** (agent-executable only):
  - [ ] `dart analyze`
  - [ ] `dart test test/mock_test.dart`
  - [ ] Workspace search for `runPhp|startProcess|killProcessTree|ManagedProcessRunner` returns no stale public references in production code or tests

  **QA Scenarios** (MANDATORY — task incomplete without these):
  ```
  Scenario: Support files fully aligned to the new contract
    Tool: Bash
    Steps:
      1. Run `dart analyze`
      2. Run `dart test test/mock_test.dart`
    Expected: Analyzer and mock tests pass with exit code 0 after terminology and import cleanup.
    Evidence: .sisyphus/evidence/task-8-contract-cleanup.txt

  Scenario: No stale public API promises remain
    Tool: Grep
    Steps:
      1. Search `D:\Codes\Algorithm\pvm\lib` and `D:\Codes\Algorithm\pvm\test` for `runPhp|startProcess|killProcessTree|ManagedProcessRunner`
      2. Confirm no stale public-facing references remain after cleanup
    Expected: No stale references remain in production code or tests.
    Evidence: .sisyphus/evidence/task-8-contract-cleanup-error.txt
  ```

  **Commit**: NO | Message: `chore(process): align imports mocks and deferred-cleanup contract` | Files: `lib/src/process/process.dart`, `lib/src/managers/mock_os_manager.dart`, `test/mock_test.dart`, related comments/tests`

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.
- [x] F1. Plan Compliance Audit — oracle ✅ **APPROVE** — Oracle verified all Tasks 1–8 satisfied. No deviations. Evidence: `.sisyphus/evidence/f1-plan-compliance.txt`

  **What to do**: Run an Oracle review against the completed implementation and compare the resulting code/tests to Tasks 1-8 in this plan. Require an explicit APPROVE/REJECT verdict with any deviations listed.
  **Tool**: `task(subagent_type="oracle")`
  **Steps**:
    1. Provide Oracle the plan file plus the final changed file list.
    2. Ask Oracle to verify that interactive default behavior, explicit PHP path ownership, captured mode availability, and deferred cleanup scope all match the plan.
    3. Record Oracle's verdict and cited deviations.
  **Expected**: Oracle returns APPROVE with no scope deviations, or returns REJECT with a concrete fix list.
  **Evidence**: `.sisyphus/evidence/f1-plan-compliance.txt`

- [x] F2. Code Quality Review — unspecified-high ✅ **PASS** — API clarity clean, no dead code, no Windows-specific leaks, strong test coverage, robust error handling. Evidence: `.sisyphus/evidence/f2-code-quality.txt`

  **What to do**: Run a high-effort code review over all modified files for API clarity, dead-code removal completeness, cross-platform safety, and test quality.
  **Tool**: `task(category="unspecified-high")`
  **Steps**:
    1. Review all changed production and test files.
    2. Verify there is no retained `ManagedProcessRunner`, `taskkill`, Job Object, or legacy public process API usage.
    3. Confirm naming, import hygiene, and error-handling consistency.
  **Expected**: Reviewer returns APPROVE with no critical issues, or REJECT with a concrete defect list.
  **Evidence**: `.sisyphus/evidence/f2-code-quality.txt`

- [x] F3. Agent-executed Runtime QA — unspecified-high ✅ **ALL PASS** — `dart analyze`: No issues found. `dart test`: 100/100 tests passed in 00:03. Evidence: `.sisyphus/evidence/f3-runtime-qa.txt`

  **What to do**: Run the full agent-executed verification suite for the completed refactor. This replaces any manual QA.
  **Tool**: `Bash`
  **Steps**:
    1. Run `dart analyze`
    2. Run `dart test test/commands/php_command_test.dart`
    3. Run `dart test test/process/io_process_manager_test.dart`
    4. Run `dart test test/adversarial_test.dart`
    5. Run `dart test`
  **Expected**: Every command exits 0; no manual intervention is required.
  **Evidence**: `.sisyphus/evidence/f3-runtime-qa.txt`

- [x] F4. Scope Fidelity Check — deep ✅ **CLEAN** — No PATH injection, no Windows-specific APIs, no legacy interfaces, only dart:io in core path. Evidence: `.sisyphus/evidence/f4-scope-fidelity.txt`

  **What to do**: Run a deep review that compares the final implementation against the allowed scope and explicit non-goals in this plan.
  **Tool**: `task(category="deep")`
  **Steps**:
    1. Compare changed files and behavior against the Must Have / Must NOT Have sections.
    2. Verify no PATH injection architecture was introduced.
    3. Verify no replacement cleanup/tree-kill mechanism was added in phase 1.
    4. Verify symlink/global/use/list behavior was not expanded beyond compile-safe rewiring.
  **Expected**: Reviewer returns APPROVE with no out-of-scope work, or REJECT with exact scope violations.
  **Evidence**: `.sisyphus/evidence/f4-scope-fidelity.txt`

## Commit Strategy
- Commit 1: characterization tests + new process contract
- Commit 2: cross-platform process implementation + php wiring
- Commit 3: legacy runner removal + regression tests + cleanup

## Success Criteria
- `PhpCommand` no longer imports or depends on `ManagedProcessRunner`
- The new public process abstraction is use-case driven (`interactive` + `captured`) instead of Windows-internal driven
- `pvm php ...` uses interactive execution by default and preserves prompt-capable terminal behavior
- Captured execution is available for tests/internal consumers without terminal inheritance
- All tests and analyzer checks pass without requiring Windows-only process APIs in the shared core path
- Deferred cleanup behavior is documented in code/tests so no false guarantee remains

## Progress Log

### 2026-03-24
- **Final Verification Wave (F1–F4) completed — ALL PASS**
  - F1 (Oracle Plan Compliance): APPROVE — all Tasks 1–8 verified, no deviations
  - F2 (Code Quality): PASS — API clean, no dead code, no Windows leaks, strong tests, robust error handling
  - F3 (Runtime QA): ALL PASS — `dart analyze` 0 issues, `dart test` 100/100 passed in 00:03
  - F4 (Scope Fidelity): CLEAN — no PATH injection, no Windows APIs, no legacy interfaces, dart:io only in core
- **Plan ready for user approval to mark complete**
