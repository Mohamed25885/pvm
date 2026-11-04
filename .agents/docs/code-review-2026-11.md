# PVM Full Code Check — 2026-11-04

**Scope:** `main` @ `1c6ffb6` (v2.0.0). Security issues are in [security-audit-2026-11.md](security-audit-2026-11.md) (IDs `S*`); this file covers correctness, design and maintainability (IDs `B*` = bug, `D*` = design/debt).

**Baseline:** `fvm dart analyze` → no issues · `fvm dart test` → 503 passed, 1 skipped · ~5.7k lines in `lib/`, 63 test files.

## Bugs

| ID | Sev | Where | Problem | Repro / evidence |
|----|-----|-------|---------|------------------|
| B1 | High | `windows_installer.dart:100-112` | Target dir is created **before** download/verify; on network error or SHA mismatch an empty `versions/8.x.y/` is left behind. The next `pvm install` says "already installed" (line 93) and `pvm list`/`use` offer a version with no `php.exe`. | Kill network mid-install, re-run |
| B2 | High | `windows_installer.dart:172-213` | Download retry loop: on a mid-stream error the `IOSink` is never closed (Windows file lock → retries fail to reopen), `downloadedBytes` isn't reset (progress >100%), and the cleanup checks `existingFile`, which was captured before download. | Read code |
| B3 | High | `use_command.dart:41-46` | `_getAvailableVersions` calls `PhpVersion.parse` without a catch; any non-version folder in `versions/` (e.g. `tmp`, `8.3-old`) makes **every** `pvm use` fail with "Invalid version format". `VersionRegistry` already skips these — UseCommand bypasses it. | `mkdir versions\tmp; pvm use 8.3` |
| B4 | High | `use_command.dart:55` | `.gitignore` is created/modified **before** the version is validated, so `pvm use bogus` (or a typo, or running outside a project) still writes `.gitignore` into the cwd. | `cd C:\; pvm use 9.9` |
| B5 | Medium | `install_command.dart:76-78` + `windows_installer.dart:55-59,93-97` | "Already installed" is printed as an error, then the command prints "Successfully installed" and exits 0. | `pvm install 8.3` twice |
| B6 | Medium | `windows_release_fetcher.dart:15-32` | Any network/HTTP/parse failure returns `[]`, so `install` reports "No matching PHP release found" instead of "network error". | Offline `pvm install 8.3` |
| B7 | Medium | `release_parser.dart` / design | `releases.json` lists only the **latest patch** per minor; `pvm install 8.3.5` (older patch) can never succeed. Older builds live under `/downloads/releases/archives/`. | `pvm install 8.2.0` |
| B8 | Medium | `php_executor.dart`, `exec_command.dart:158-183` | `pvm php`, `pvm composer` and the php/composer branches of `pvm exec` don't prepend the selected PHP dir to `PATH`. Child processes (Composer scripts calling `php`, `artisan` spawning `php`) silently use the **global** PHP. Only the generic `exec` branch sets PATH. | `pvm composer run-script x` where script calls `php -v` |
| B9 | Medium | `domain/php_version.dart:31` | Very large numbers throw `FormatException` (not `InvalidVersionFormatException`) and escape command handlers as "Unexpected error". | Probe: `PhpVersion.parse('99999999999999999999.1')` |
| B10 | Medium | `install_command.dart:91-105` | Its own `_parseVersion` accepts `8.3.x` / `8.3.1.9` and passes the raw string on; parsing should use `PhpVersion.parse` once. | `pvm install 8.3.1.9` |
| B11 | Medium | `windows_installer.dart:99-116` | `--force` extracts over the old tree; stale DLLs/extensions from the previous build remain. | Reinstall with `--force` |
| B12 | Low | `list_command.dart:39-41` | No versions → exit code 1 with **no message**. | Empty `versions/` |
| B13 | Low | `exec_command.dart:227` | `pvm exec --version` (no value) is treated as the command `--version`. `--cwd` to a missing dir throws past the handler from the php branch. | `pvm exec --cwd X:\nope -- php -v` |
| B14 | Low | `php_command.dart` vs README | README documents "No local version configured…" but actual output is "Error running PHP: PHP executable not found…" with `generalError` (1) instead of `configurationError`. | `pvm php -v` outside a project |
| B15 | Low | `php_version_manager.dart:34-36` | Doc comment says default **No**; README and `confirm()` default **Yes**. | Read code |
| B16 | Low | Unix activators | Link `.pvm/php` (file) while Windows links `.pvm` → version dir. `SymLinkInspector` reports Unix `.pvm` as `corrupt`, so `current`, `doctor`, `exec` fallback and `uninstall` are wrong on Linux/macOS. Unix `activateLocal` also uses cwd, not project root. | Read code |

### Found later (Phase 1 end-to-end run)

| ID | Sev | Where | Problem | Status |
|----|-----|-------|---------|--------|
| B17 | High | `pvm.dart` `main` | `Future<int> main` returned the exit code, but Dart ignores `main`'s return value, so the process **always exited 0**, including PHP's own status from `pvm php`. | Fixed in Phase 1 |
| B18 | High | `release_parser.dart` | `"8.4.27-1"` (Windows rebuild suffix) → `int.tryParse("27-1") == null` → patch 0. `pvm install 8.4` installed 8.4.27 into `versions/8.4.0`, which affected all current 8.2–8.5 releases. | Fixed in Phase 1 |

## Design / debt

| ID | Where | Issue | Recommendation |
|----|-------|-------|----------------|
| D1 | `services/php_downloader.dart` (131 lines) | Unused; duplicates download + SHA logic. | Delete. |
| D2 | `gitignore_service.dart:59-87` | `ensurePvmSymlinkExists` unused, uses raw `dart:io`, and does `File(dir).delete(recursive:true)` (see S2). Two `// ignore: unused_field`. | Delete method and unused fields. |
| D3 | `project.dart`, `php_executor.dart`, `windows_os_manager.dart:43`, `linux_os_manager.dart`, `mac_os_manager.dart` | Direct `Platform.environment` / `Directory`/`File` despite the `IOSManager` abstraction (AGENTS.md rule §7). Makes S3 untestable. | Inject `IOSManager` into `Project`; route env through `currentEnvironment`. |
| D4 | `windows_installer.dart` | Uses `dart:io` + `http` directly; creates its own `http.Client` in the constructor (also when only `list` runs, due to lazy singletons this is OK, but untestable). | Inject `http.Client` and a filesystem port. |
| D5 | Install vs versions layout | Windows: `versions/<v>/php.exe`. Unix code assumes `versions/<v>/bin/php`. `ExecCommand`/`ExecutableResolver` hard-code the Windows layout. | Introduce a `PhpLayout` (binDir, phpExe) per platform — prerequisite for cross-platform. |
| D6 | `WindowsPrivilegeEscalator` | Production stub; whole escalation stack is effectively dead on Windows. | Replace symlinks with junctions (no privilege), keep escalation only for the symlink fallback, or remove. |
| D7 | `pvm.dart` | Composition root registers everything with `get_it`, then pulls everything back out to construct commands; `get_it` adds little. | Optional: plain constructor wiring in a `buildRunner()` function that tests can call. |
| D8 | Error model | Mix of `throw Exception('Error: …')` strings, `PvmException` subtypes, and `printError` + return codes; messages often double-prefixed ("Error: Exception: Error: …"). | One `PvmException` hierarchy with exit codes; single top-level renderer. |
| D9 | `WindowsOSManager.createSymLink` | Parameter named `homeDir` is actually the link's parent; first argument `version` unused. | Rename; drop unused param from `IOSManager`. |
| D10 | Repo hygiene | `.sisyphus/` is in `.gitignore` but its 17 files are still tracked (committed before the ignore rule); same for `.fvm/fvm_config.json` under an ignored `.fvm/`. Many finished plans in `.agents/plans/`. | `git rm -r --cached .sisyphus`; decide whether `.fvm/fvm_config.json` stays (then un-ignore it explicitly); move "Done" plans to `.agents/plans/archive/`. |
| D11 | Docs drift | README says Windows-only, but `pvm.dart` wires Linux/macOS paths that don't work end-to-end (B16, S6). AGENTS.md says `IOProcessManager` uses `ProcessStartMode.normal`; the code uses `inheritStdio`. | Fix docs in the same PR as the behaviour. |
| D12 | Tests | Strong unit coverage, but nothing exercises a real install, real symlink/junction creation, or the home-dir / non-version-folder cases (B3, S3). CI is Windows-only. | Add the regression tests listed in the roadmap; add Linux/macOS CI jobs. |

## Strengths worth keeping
- Clear layering (commands → domain/core → managers) and interface-first design; almost everything is mockable.
- Sealed result types for version resolution (`InstalledVersionResolveResult`) with exhaustive `switch`.
- Consistent user messaging via `VersionDiagnostics`; interactive vs non-interactive behaviour is explicit.
- Formatting, `analyze --fatal-infos`, 60% coverage gate and OSV in CI.
