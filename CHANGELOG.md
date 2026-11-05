# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased](https://github.com/Mohamed25885/pvm/compare/v2.1.0...HEAD)

## [2.1.0](https://github.com/Mohamed25885/pvm/compare/v2.0.0...v2.1.0) - 2026-11-05

### Added
- **No admin rights or Developer Mode needed.** `.pvm` links are created as directory junctions, with a symbolic link as fallback only, for example when versions live on a network share.
- **`pvm install <major.minor.patch>` can install older patches** from the windows.php.net archive. The archive publishes no checksums, so this requires `--allow-unverified` and prints a warning.
- **Install record.** Every install writes `versions/<v>/.pvm-install.json` with the source URL, whether the build was verified, and a SHA-256 of each file.
- **`pvm doctor --verify`** re-hashes installed versions and reports modified or missing files, unverified sources, and versions without a record.
- **CI writes a `SHA256SUMS` file** next to `pvm.exe` and attests build provenance on pushes to `main`.

### Changed
- **The selected PHP comes first on `PATH`** for `pvm php`, `pvm composer` and every `pvm exec` branch. Child processes, such as Composer scripts and `artisan` spawning `php`, now use the same version instead of the global one. The existing `Path`/`PATH` key is reused, so no duplicate variable is created.
- **`pvm install` messages are clearer:**
  - "already installed" is a success (exit 0), not an error followed by "Successfully installed".
  - A network failure is reported as a network error, not as "No matching PHP release found".
  - The concrete version installed is printed (`8.3` → `8.3.14`).
- **No elevation prompt that can't work.** When a link can't be created for lack of privilege, PVM explains how to fix it instead of offering to "elevate and retry".
- **One version parser everywhere.** Each part is limited to 4 digits, so huge numbers are rejected cleanly instead of crashing, and `pvm install` uses the same parser as the other commands.
- **Errors no longer read "Error: Exception: Error: …".**
- **CI hardening:**
  - Actions are pinned to commit SHAs: `actions/checkout` v3 → v7.0.1, `upload-artifact` v4 → v7.0.2, `setup-dart` v1.8.1, OSV workflow v2.2.4.
  - Default permissions are `contents: read`, and checkout no longer persists credentials.

### Security
- **`pvm setup` no longer truncates the user `PATH`.** Values are written with `reg add` instead of `setx`, which cut values at 1024 characters and replaced `REG_EXPAND_SZ` with `REG_SZ`. The existing value type is preserved, and the previous `Path` is backed up to `%LOCALAPPDATA%\pvm\backups\`. The write is refused if any existing entry would be lost, or if `PATH` can't be read. `WM_SETTINGCHANGE` is broadcast afterwards.
- **PVM never deletes a real file or directory at a `.pvm` link slot.** Previously such a directory was deleted recursively without asking. Only existing links are replaced; anything else aborts with a clear message.
- **`pvm use` refuses to run in the home directory or at a filesystem root.** Running it in `%USERPROFILE%` used to overwrite the global version link. The Windows activator also refuses to create a local link on top of the global one.
- **Zip extraction aborts on unsafe entries.** This covers entries that resolve outside the target (including a sibling version such as `8.3.1` → `8.3.10`), absolute paths, drive letters, and symlinks.
- **Composer lookup ignores empty and relative `PATH` segments,** so a cloned repository can no longer plant its own `composer.phar` through a trailing `;` in `PATH`. Commands that aren't found on `PATH` now fail instead of being passed to the OS by bare name, which on Windows would search the current directory first.
- **Download URLs must be `https` on an allowed host or one of its subdomains.** Look-alike hosts such as `evilwindows.php.net` are rejected. An empty checksum fails verification.

### Fixed
- **`pvm install` is transactional.** The download goes to a private temp directory and is verified, then extracted into a staging directory and checked for `php.exe` before being moved into `versions/<v>`. A failed download or a checksum mismatch no longer leaves an empty version directory that then shows up as "installed".
- **`pvm install --force` replaces the whole version tree,** so no stale DLLs or extensions are left behind. If the version directory exists but has no `php.exe`, it is repaired instead of being reported as already installed.
- **Download retries now work.** Each failed attempt closes its file handle, cleans up its partial file and resets progress.
- **`pvm use` ignores folders in `versions/` that aren't versions** (e.g. `tmp`). Previously such a folder broke every `use`.
- **`pvm use` only touches `.gitignore` after a successful activation,** and treats a failure there as a warning.
- **`pvm use` resolves the project from the same working directory as the activator.**

- **PVM always exited with code 0.** Dart ignores `main`'s return value, so every failure, and PHP's own exit status from `pvm php` / `pvm exec`, reached the shell and CI as success. The exit code is now set explicitly.
- **`pvm install 8.4` installed PHP 8.4.27 into a folder named `8.4.0`.** windows.php.net labels rebuilt binaries `8.4.27-1`, and the parser turned the patch into 0. This affected every current 8.2–8.5 release. The archive index also understands rebuild suffixes and prefers the newest rebuild.
- **`pvm list` with no installed versions** now prints a message and a hint, instead of exiting with code 1 silently.
- **`pvm exec` rejects `--version` and `--cwd` without a value,** and rejects a `--cwd` directory that doesn't exist.
- **`pvm php` outside a configured project** prints the documented "No local version configured" message, with exit code 6.
- **Linux/macOS package-manager install check:** a same-major PHP (e.g. 8.1 when 8.4 was requested) no longer counts as "already installed".

### Removed
- Unused `GitIgnoreService.ensurePvmSymlinkExists`, which recursively deleted the slot.
- Unused `services/php_downloader.dart`.
- `.sisyphus/` agent scratch files from version control (already in `.gitignore`).

## [2.0.0] - 2026-05-25

### Added
- **`pvm setup`** — optional first-run configuration: validates directories and permissions, creates `versions/` when missing, may set user env vars (`PVM_HOME`, `PVM_VERSIONS_HOME`) and PATH entries (`pvm` directory + `%USERPROFILE%\.pvm`). Flags: `--dry-run`, `--yes`, `--versions-home <path>`.
- **`PvmPaths`** — resolves install locations from optional `PVM_HOME` / `PVM_VERSIONS_HOME` with fallbacks to the executable directory and `<home>/versions` (unchanged behavior when env vars are unset).
- **Privilege escalation** — `ElevatingOSManager` wraps symlink creation; on permission denial, prompts to retry (Developer Mode or Administrator). `WindowsPrivilegeEscalator` stub on Windows; full UAC re-launch not required when Developer Mode is enabled.
- **`InstalledVersionResolver`** — shared `major.minor` shorthand for `use`, `global`, `exec`, and `uninstall`; `VersionDiagnostics.ambiguousVersionMessage` when multiple patches match.
- **`ProjectPvmrcCheck`** in `pvm doctor` (replaces `.php-version` project check).
- Policy test `test/policy/no_php_version_runtime_test.dart` — no `.php-version` string literals in `lib/src` runtime code.
- FVM project config (`.fvmrc`, Flutter **3.41.6** → Dart **3.11.4**); CI runs via `fvm dart`.
- Integration tests under `test/integration/`.

### Changed
- **Breaking:** Project version file is **`.pvmrc`** (JSON, e.g. `{"version": "8.2"}`). PVM no longer reads, writes, or discovers **`.php-version`** at runtime (avoids conflicts with Apache and other tools that use that filename). Re-run `pvm use <version>` or create `.pvmrc` manually to migrate.
- **Breaking:** Project root discovery walks **`.pvmrc`** first, then **`.pvm/`** marker; falls back to CWD when neither exists.
- **Breaking:** **`pvm exec`** and **`pvm uninstall`** no longer auto-select the newest patch when `major.minor` is ambiguous — specify full `major.minor.patch` when multiple versions share the same line.
- **Version shorthand:** `pvm use`, `pvm global`, `pvm exec`, and `pvm uninstall` accept `8.4` when exactly one installed `8.4.x` exists.
- `WindowsOSManager`, `LinuxOSManager`, and `MacOSManager` delegate `programDirectory` / `phpVersionsPath` to `PvmPaths.fromEnvironment`.
- Minimum Dart SDK: `>=3.11.0 <4.0.0` (development pinned via FVM).

### Removed
- Runtime dependency on `.php-version` filename and `phpVersionFileName` constant.

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
