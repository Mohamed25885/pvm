## Plan Title: Root .php-version behavior for pvm

## TL;DR
- Implement a root-level .php-version file to remember the last used local PHP version and alter pvm use behavior when no version is provided or when a mismatch occurs.
- If .php-version exists and no version is given to pvm use, apply that version automatically.
- If a version is provided that differs from the value in .php-version, prompt the user to confirm switching; on approval, update .php-version and switch locally.

## Context
- Original Request: Add root-level .php-version support to improve UX when no version is provided and to prompt on mismatches.
- Scope: Non-breaking changes, mockable prompts, DI-friendly integration.

## Work Objectives
- Read/write a .php-version file at repository root.
- Read last used version; apply as default on no-arg pvm use.
- If mismatch occurs, prompt user and update .php-version and switch locally.
- Extend UseCommand tests to cover both default behavior and prompts.
- CLI-driven defaults: add support for --root-path, --no-prompt, and --auto-accept; env vars are intentionally not used at this time.

## CLI Flags (Design)
- Root override: --root-path to set the repository/workspace root for this invocation.
- Non-interactive mode: --no-prompt to disable prompts; --auto-accept to switch automatically when .php-version exists and mismatch occurs (only in non-interactive contexts).
- UseCommand and PhpVersionManager should honor these flags via DI wiring (tests should mock user input for interactive prompts).
- Read/write a .php-version file at repository root.
- Read last used version; apply as default on no-arg pvm use.
- If mismatch occurs, prompt user and update file on consent.
- Extend UseCommand tests to cover both default behavior and prompts.

## Definition of Done
- .php-version file exists and is respected by default when no argument is provided.
- Prompt is shown for mismatches; user acceptance updates the file and applies the change.
- All tests pass; no breaking changes to existing flows.

## Must Have
- Access to repository root for reading/writing .php-version.
- Non-blocking behavior when .php-version does not exist.
- Promptable UI for version mismatch (mockable in tests).

## Must NOT Have
- No forced defaults that override user intent without explicit prompt.
- No hard-coded prompts without a mockable path.

## Phases
- Phase 1: Design
  - Define API surface: PhpVersionManager with readLastUsedVersion, writeCurrentVersion, promptIfVersionMismatch.
- Phase 2: Implementation
  - Implement root .php-version IO and prompt integration in UseCommand.
- Phase 3: Testing
  - Add tests for read/write and prompt flow; adapt UseCommand tests.
- Phase 4: Integration
  - Wire DI into UseCommand; pass PhpVersionManager to commands.
- Phase 5: Rollout
  - Documentation; user-facing guidance.

## Execution Strategy
- Parallel Waves: Design/Implementation and Testing in parallel where feasible.
- Dependencies: UseCommand depends on PhpVersionManager.

## TODOs
- [ ] Create lib/src/core/php_version_manager.dart
- [ ] Extend lib/src/commands/use_command.dart to use PhpVersionManager
- [ ] Add tests for PHP version management
- [ ] Add plan artifact: root_php_version_behavior.md

## References
- Mirrors style and intent of existing plan docs in .sisyphus.

## Progress Log
- 2026-03-25: Plan drafted for root .php-version support; awaiting patch application
