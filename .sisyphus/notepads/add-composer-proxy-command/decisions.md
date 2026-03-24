# Architectural Decisions

## 1. PhpExecutor Service Design
- **Decision**: Create a dedicated service class that encapsulates all PHP execution logic.
- **Rationale**: Both `PhpCommand` and upcoming `ComposerCommand` need to run PHP with consistent behavior. Centralizing in `PhpExecutor` avoids duplication and ensures single source of truth for PHP path resolution and process spec construction.

## 2. Dependencies
- **Decision**: `PhpExecutor` depends on `IProcessManager` (for execution) and `IOSManager` (for file checks and current directory).
- **Rationale**: `IProcessManager` provides the actual process launching; `IOSManager` provides filesystem abstraction. `PhpExecutor` is a thin coordination layer.

## 3. Environment Handling
- **Decision**: Use `Platform.environment` directly, not via OS manager.
- **Rationale**: `IOSManager` interface does not expose environment; `Platform.environment` is standard Dart and fits the spec. This keeps PhpExecutor simple and avoids expanding OS interface.

## 4. Error Policy
- **Decision**: `_resolvePhpExecutable` throws `Exception` if PHP binary missing.
- **Rationale**: Immediate fail-fast; calling command can catch and print user-friendly error. No silent fallback to system PHP.

## 5. Test Double Placement
- **Decision**: Place `FakeProcessManager` and `FakeOSManager` in `test/services/` as separate files.
- **Rationale**: SOLID — each fake serves a single responsibility. They are test-specific and should not pollute `lib/src/`.

## 6. Test Helper Function
- **Decision**: Keep `getPhpExe(String rootPath)` helper inside test file (not extracted).
- **Rationale**: Only used in tests; simple enough; avoids extra file.

## 7. ProcessSpec Construction
- **Decision**: Always set `environment: Platform.environment` in ProcessSpec.
- **Rationale**: Ensure child process inherits environment; important for PATH, etc.

---

## Rejected Alternatives

- **Alternative**: Put fakes in `lib/src/managers/` like existing `MockOSManager`.
  - **Rejected because**: That would mix test code with production code. Test doubles belong in `test/`.

- **Alternative**: Have `PhpExecutor` accept only `IProcessManager` and use direct `File` calls for existence check.
  - **Rejected because**: Violates abstraction — we must use `IOSManager` for filesystem operations to maintain testability and cross-platform consistency.

---
