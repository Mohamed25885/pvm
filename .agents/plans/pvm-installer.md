# PVM Installer / Setup

## Status
Done

## Description
`pvm setup` configures `PVM_HOME`, `PVM_VERSIONS_HOME`, and user `PATH` via platform environment configurators, with preflight checks before writes.

## Phases
### Phase 1: Paths and preflight
- Status: Done
- `PvmPaths`, `SetupPreflight`, writable probes

### Phase 2: Setup service and command
- Status: Done
- `PvmSetupService`, `SetupCommand`, dry-run and `--yes`

### Phase 3: Windows persistence
- Status: Done
- `WindowsEnvironmentConfigurator` via `reg` / `setx`

## Progress Log

### 2026-05-25
- Setup command registered in `pvm.dart`
- Fake and Windows configurator tests; noop contract on non-Windows CI

## Conclusion
First-run setup can persist directories and PATH on Windows without manual env editing.

## Suggestions
- Broadcast `WM_SETTINGCHANGE` after PATH updates for live shells
