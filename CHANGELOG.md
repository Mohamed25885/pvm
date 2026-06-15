# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased](https://github.com/Mohamed25885/pvm/compare/v1.2.0...HEAD)

### Changed
- **Version shorthand:** `pvm use`, `pvm global`, `pvm exec`, and `pvm uninstall` accept `major.minor` (e.g. `8.4`) when exactly one installed version matches; if multiple patches exist (e.g. `8.4.0` and `8.4.1`), the full `major.minor.patch` is required. **Breaking:** `pvm exec` and `pvm uninstall` no longer auto-select the newest patch when ambiguous.
- **Breaking:** Project version configuration moved from `.php-version` to `.pvmrc` (JSON). PVM no longer reads, writes, or discovers `.php-version` at runtime. Re-run `pvm use <version>` (or create `.pvmrc` manually) to migrate existing projects.
- Project root discovery walks for `.pvmrc` first, then `.pvm/` marker; legacy `.php-version` files are ignored.
- `pvm doctor` project check renamed to `ProjectPvmrcCheck` (`.pvmrc` label).

## [1.2.0] - 2026-05-04

### Added
- `pvm current` command — reports the effective PHP version across global and local scopes via `ActiveVersionResolver`, and flags drift between `.php-version` and the local `.pvm` symlink target.
- `pvm doctor` command — runs environment diagnostics (versions directory, global/local symlink integrity, optional symlink probe with `--no-symlink-test`).
- `pvm uninstall <version>` command — removes an installed PHP version directory with `--yes` (skip confirmation), `--force` (allow removing the active global version), and `--keep-symlinks` (leave dangling symlinks for manual cleanup).
- `pvm exec [--version <ver>] [--cwd <dir>] -- <cmd> [args]` command — runs a command (php, composer, or generic) under a chosen PHP on `PATH`; supports an optional leading version positional and `--`-aware command parsing.
- `SymLinkInspector` and `ActiveVersionResolver` core abstractions for cross-platform symlink inspection and effective-version resolution.
- `IOSManager` symlink helpers: `isSymLink`, `readSymLinkTarget`, `deleteSymLink`, and `deleteDirectory`, implemented on Windows, Linux, and macOS managers (mocks/fakes updated).
- `VersionDiagnostics.notInstalledMessage` shared helper for consistent "version not installed" CLI messaging.
- `ConsoleConfirm` extension on `Console` for yes/no prompts; consumed by `PhpVersionManager.promptMismatch` and `UninstallCommand`.
- `lib/src/services/diagnostics/` — diagnostic check abstraction (`DiagnosticCheck`), models, and `doctor_checks.dart` implementations consumed by `DoctorCommand`.
- `PhpExecutor.runPhp` / `runScript` accept optional `phpExecutable` and `environment` overrides so commands like `pvm exec` can pin a specific installed PHP and adjust `PATH` without relying on the default `.pvm` resolution.
- Characterization tests for `Project`, `VersionRegistry`, `WindowsVersionActivator`, `ExecutableResolver`, `ComposerLocator`, and `WindowsOSManager.getAvailableVersions`.
- Full command-level tests for `CurrentCommand`, `DoctorCommand`, `UninstallCommand`, and `ExecCommand`, plus unit coverage for new core/domain types.
- `MockOSManager.mockEnvironment` for deterministic `PATH` in doctor/exec tests; falls back to `Platform.environment` when unset.
- Project-local RTK configuration: `.rtk/filters.toml` (`schema_version = 1`) for optional compact CLI output when using [rtk](https://github.com/rtk-ai/rtk).

### Changed
- DRY consolidation: `PhpVersionManager.readLastUsedVersion` / `writeCurrentVersion` delegate to `Project`.
- `WindowsVersionActivator` uses `Project.findFromPath` for project-root discovery.
- `GlobalCommand` uses `VersionRegistry` and now returns `ExitCode.versionNotFound` when the requested version is missing, with a unified `VersionDiagnostics` message.
- `WindowsOSManager.getAvailableVersions` uses `p.basename` for cross-platform path correctness.
- Documentation: `AGENTS.md` updated with new architecture (symlink helpers, `SymLinkInspector` / `ActiveVersionResolver`, diagnostics, `Console` confirm, `PhpExecutor` overrides), expanded command list, uninstall flag semantics, and corrected mock locations under `test/mocks/`. `CLAUDE.md` includes a brief PVM section pointing to `AGENTS.md`.

## [1.1.0] - 2026-04-25

### Added
- Extracted `PlatformDetector` as single OS truth source.
- Added explicit HTTPS enforcement protecting PVM from unsafe releases inside `WindowsInstaller`.
- Added structural version parameter path guards via `PhpVersion.parse`.

### Changed
- Refactored `InstallCommand` delegating extraction workflows natively into `IInstaller`.
- Centralized all constants inside `core/constants.dart`.

### Fixed
- Fixed version directory resolution discrepancy based on terminal elevation contexts on Windows.
- Fixed `File().delete()` crashing symmetric link collisions during `pvm use` / `pvm global`.
## [1.0.1] - 2026-04-18

### Added
- Composer proxy command (`pvm composer`)
- `pvm version` flag support
- Console UI improvements with colors and formatting
- Exit codes module for better error handling

### Fixed
- Various bug fixes and improvements

---

## [1.0.0] - 2025-03-25

### Added

- Initial release of PVM (PHP Version Manager)
- `pvm global` command to set system-wide PHP version
- `pvm use` command to set project-local PHP version
- `pvm list` command to list available PHP versions
- `pvm php` proxy to run PHP with local version
- `pvm composer` proxy to run Composer with local PHP
- Windows symbolic link management for fast version switching
- Interactive and non-interactive mode support
- Project root discovery via `.php-version` file
- Automatic `.gitignore` management for `.pvm` directory
- Version format validation (x.y or x.y.z)
- Mismatch detection and confirmation prompts
- Support for Developer Mode and Administrator privileges

---

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). All future changes will be documented in the [Unreleased] section above and moved to a new version section upon release.
