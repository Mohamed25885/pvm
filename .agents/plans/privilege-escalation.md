# Privilege Escalation

## Status
Done

## Description
Classify symlink permission errors, prompt for elevation, retry `createSymLink` once via `ElevatingOSManager` decorator.

## Phases
### Phase 1–5: TDD modules
- Status: Done
- `permission_error`, `privilege_escalation_service`, `elevating_os_manager`, wired in `pvm.dart`

## Progress Log

### 2026-05-25
- Branch `feature/privilege-escalation` from `main`
- Mock-only elevation tests; `WindowsPrivilegeEscalator` production stub
- Integrated on `feature/pvm-integration`: `elevating_os_manager_test`, `privilege_escalation_service_test`, activator elevation test

## Conclusion
Elevation path integrated without real UAC in CI.
