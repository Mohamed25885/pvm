## Plan Title: GitIgnoreService + Root .php-version integration (no Git existence check)

## TL;DR
Add two non-blocking features:
- GitIgnoreService to ensure a repo-level .gitignore exists and ignores the .pvm symlink; best-effort symlink creation for .pvm if possible.
- Root-level .php-version support to remember the last local PHP version used and prompt on mismatches when using a different version via pvm use.

Deliverables: a pair of cohesive services wired into the CLI with tests, documentation, and a plan for progressive rollout.

## Context
- Original Request: Implement GitIgnoreService and root .php-version support; do not block startup on Git availability.
- Scope: Implement cross-platform features with safe fallbacks; tests mock external prompts and OS specifics.

## Work Objectives
- Introduce GitIgnoreService and PhpVersion management as DI-friendly services.
- Wire into the CLI (UseCommand) with explicit, testable DI points.
- Implement default behaviors via CLI flags (no env vars) as described below.
- Ensure non-blocking, best-effort behavior for symlink creation and gitignore updates.
- Document decisions and guardrails for future audits.

## Defaults and CLI Flags (Decision Complete)
- Root Path discovery: The root path is determined by locating the nearest ancestor directory that contains the .pvm symlink. If none is found, it defaults to the directory from which the CLI was invoked. The root-path override flag (--root-path) allows explicit per-run overrides. 
- Root Path default: repository root. Override via CLI flag --root-path (or --root-path option on commands) to apply to a specific workspace root.
- Symlink Creation: Best-effort; if creation fails due to permissions or platform limitations, log a non-fatal warning and proceed without crashing.
- Prompt UX:
  - Interactive mode (TTY): Prompt the user when a mismatch is detected between requested and last-used versions.
  - Non-interactive fallback: If not a TTY or if --no-prompt is supplied, do not prompt. If --auto-accept is supplied, automatically switch to the requested version when a mismatch occurs and update .php-version accordingly; otherwise, leave as-is.
- Environment variables are NOT used for overrides in this phase; only CLI flags apply. The root-path override via --root-path takes precedence over any auto-detected root.
- Dependency Injection: Use DI to provide GitIgnoreService and PhpVersionManager to UseCommand and Php-related commands, enabling easy mocking in tests.

## Acceptance Criteria (CD: CLI-only defaults)
- The CLI accepts: --root-path, --no-prompt, --auto-accept flags for the relevant commands.
- GitIgnoreService updates .gitignore and attempts to create .pvm symlink without crashing if permissions fail.
- PhpVersionManager reads/writes .php-version and prompts on mismatches when there is a TTY; non-interactive fallback with --no-prompt or --auto-accept is wired.
- Tests exist to validate CLI flag-driven behavior without env vars.

## Notes for Future
- If you later decide to support environment-based overrides, plan revisions to enable an environment variable switch; for now, CLI-only controls keep behavior explicit and testable.
- DI usage should be consistently applied across commands; inject mocks in tests to verify behavior without touching the file system or OS primitives.

- Introduce lib/src/core/gitignore_service.dart with API:
  - Future<void> ensureGitignoreIncludesPvm({required String rootPath})
  - Future<void> ensurePvmSymlinkExists({required String rootPath})
- Introduce lib/src/core/php_version_manager.dart with API:
  - Future<String?> readLastUsedVersion({required String rootPath})
  - Future<void> writeCurrentVersion({required String rootPath, required String version})
  - Future<bool> promptIfVersionMismatch({required String requestedVersion, required String rootPath})
- Enhance lib/src/commands/use_command.dart to use PhpVersionManager and GitIgnoreService (DI) and implement behavior:
  - No-arg: auto-apply .php-version if present.
  - With version: prompt on mismatch; update .php-version if confirmed.
- Add tests under test/ for both services and integrate with existing UseCommand tests.
- Create plan docs and plan-draft artifacts.

## Definition of Done
- GitIgnoreService:
  - .gitignore is created if missing; includes a robust line to ignore .pvm (e.g., /.pvm).
  - Best-effort creation of the .pvm symlink; non-fatal if not supported.
- PHP-version management:
  - .php-version file read/written at repository root.
  - No-arg pvm use consumes .php-version when present.
  - Mismatched version prompts and, if confirmed, updates .php-version and switches locally.
- Tests exist for both services; existing tests adapted as needed to cover new flows.
- Patches apply cleanly and pass CI when run with the test suite.

## Phases
- Phase 1: Design
  - Define APIs and DI wiring; decide on rootPath default (repository root).
- Phase 2: Implementation
  - Implement gitignore_service.dart and php_version_manager.dart; wire into UseCommand.
- Phase 3: Testing
  - Implement unit tests for both services; update UseCommand tests.
- Phase 4: Integration
  - Integration tests; ensure no startup breakages if Git is absent.
- Phase 5: Rollout
  - Documentation; user-visible behavior notes; feature flags if needed.

## Execution Strategy
- Parallel Execution Waves: 2 waves (design/implementation and tests/integration) in parallel where possible.
- Dependencies: UseCommand wiring depends on PhpVersionManager and GitIgnoreService.

## TODOs
- [ ] Create lib/src/core/gitignore_service.dart
- [ ] Create lib/src/core/php_version_manager.dart
- [ ] Extend lib/src/commands/use_command.dart for DI and new behaviors
- [ ] Add tests: test/gitignore_service_test.dart, test/php_version_manager_test.dart
- [ ] Extend tests for UseCommand
- [ ] Add plan artifact: .sisyphus/plans/add_gitignore_and_php_version.md (this file)
- [ ] Draft plan: .sisyphus/drafts/add_gitignore_and_php_version.md
- [ ] Update references in README/help if needed

## References
- This plan aligns with the previous plan style in .sisyphus/plans/managed-process-runner-refactor.md
- Root path assumptions: repository root is the default rootPath; allow overrides via DI for workspace-specific roots

## Progress Log
- 2026-03-25: Plan drafted for two features; awaiting patch application and design sign-off
