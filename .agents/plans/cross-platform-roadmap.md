# Cross-Platform Roadmap (v2.0.x → v3.0.0)

## Status
Proposed

## Description
Take PVM from "Windows-only, with half-wired Unix code" to a first-class PHP version manager on **Windows, Linux and macOS** (x64 + arm64).
The order is deliberate: **fix what is broken and unsafe first** (Phases 0–1, shippable as v2.0.x/v2.1.0), **then** refactor the foundations (Phase 2) and build the new platforms on top of them (Phases 3–6, v3.0.0).

Inputs: [security-audit-2026-11.md](../docs/security-audit-2026-11.md) (`S*`) and [code-review-2026-11.md](../docs/code-review-2026-11.md) (`B*`, `D*`).

Rule for every task: **regression test first** (fails on current `main`), then the fix, then docs in the same PR.

---

## Phases

### Phase 0: Critical bug & security fixes → release v2.0.1
- Status: Done (branch `fix/phase-0-critical`; S7 from Phase 1 pulled in, since the installer was being rewritten anyway)
- Goal: nothing PVM does can destroy user data or leave the install in a broken state.

| # | Task | Refs | Done when |
|---|------|------|-----------|
| 0.1 | Write user `Path` via registry (`REG_EXPAND_SZ`, value type preserved), back up previous value, refuse to shrink, broadcast `WM_SETTINGCHANGE` | S1 | Test with a 3000-char PATH round-trips unchanged + new entries |
| 0.2 | `createSymLink`: only replace links/junctions; abort with clear error on a real dir/file at the slot; stop swallowing errors | S2 | Test: real `.pvm` dir with a file inside survives `pvm use` |
| 0.3 | Refuse `pvm use` when the project root resolves to home or a filesystem root; read home via `IOSManager` | S3, D3 | Test: `use` in home → error, global link untouched |
| 0.4 | Zip extraction: `p.isWithin` check, abort on violation, write normalized path, reject absolute/drive/symlink entries | S4 | Test: `../8.3.10/php.exe` entry aborts install |
| 0.5 | Install is transactional: download to temp, verify, extract into `versions/.staging-<v>`, atomic rename; clean up on any failure; `--force` replaces the whole tree | B1, B2, B11, S9 | Test: SHA mismatch leaves no `versions/<v>` dir |
| 0.6 | Fix download retry loop (close sink, reset counters, correct cleanup) | B2 | Test with a fake client that fails mid-stream once |
| 0.7 | `UseCommand` uses `VersionRegistry` (skips non-version dirs) | B3 | Test: `versions/tmp` present, `pvm use 8.3` works |
| 0.8 | Touch `.gitignore` only after a successful activation | B4 | Test: failed `use` leaves cwd untouched |
| 0.9 | Composer/command lookup ignores empty & relative PATH segments; unresolved commands fail instead of falling back to bare name | S5, S10 | Test: `PATH="C:\a;"` + `composer.phar` in cwd → not used |

Exit criteria: all tests green on Windows CI, CHANGELOG entry, tag `v2.0.1`.

### Phase 1: Correctness & UX fixes → release v2.1.0
- Status: Done (branch `feat/phase-1-correctness`, based on `fix/phase-0-critical`)

| # | Task | Refs |
|---|------|------|
| 1.1 | Replace symlinks with **directory junctions** for `.pvm` on Windows (no admin / Developer Mode needed); keep symlink as fallback; remove or truthfully reword the elevation prompt | S11, D6 |
| 1.2 | Prepend the selected PHP dir to `PATH` for `pvm php`, `pvm composer` and all `pvm exec` branches | B8 |
| 1.3 | Distinguish "network error" from "no matching release"; support older patches via `/downloads/releases/archives/` | B6, B7 |
| 1.4 | "Already installed" is a success message with exit 0, not error + "Successfully installed" | B5 |
| 1.5 | Single version parser: `PhpVersion.parse` everywhere, bounded digit count (≤ 4 digits/part) so overflow → `InvalidVersionFormatException` | B9, B10 |
| 1.6 | Small UX: `pvm list` empty message; `exec --version` without value → usage error; `--cwd` validation; `pvm php` message/exit code match README | B12–B15 |
| 1.7 | Host allow-list exact/subdomain match + scheme check; record installed SHA in `versions/<v>/.pvm-install.json`; `pvm doctor --verify` | S7, S8 |
| 1.8 | Cleanup: delete `php_downloader.dart`, `ensurePvmSymlinkExists`, unused fields; unify error model so messages aren't double-prefixed | D1, D2, D8, D9 |
| 1.9 | CI hardening: `checkout@v4`, pin actions by SHA, `permissions: contents: read`, release checksums + provenance; untrack `.sisyphus/` | S12, D10 |

Exit criteria: tag `v2.1.0`; README/AGENTS.md drift fixed (D11).

### Phase 2: Cross-platform foundations (refactor, no new features)
- Status: In progress on `feat/phase-2-foundations`. 2.1–2.5 are done. 2.1 covers `binDirectory` and `phpExecutable`; `extensionDir`/`iniPath` are deferred to 3.5, where they're first needed. 2.4 dropped the Unix `~/.pvm/versions` guess early, so 5.2 starts from the shared `PvmPaths` rules.
- Goal: one code path for all OSes; platform differences isolated behind small interfaces.

| # | Task | Notes |
|---|------|-------|
| 2.1 | **`PhpLayout`** abstraction: `binDir(versionDir)`, `phpExecutable(versionDir)`, `extensionDir`, `iniPath` | Windows: `<v>\php.exe`; Unix: `<v>/bin/php`. Replaces hard-coded paths in `ExecutableResolver`, `ExecCommand`, `WindowsInstaller.isInstalled`, activators (D5) |
| 2.2 | **One link model everywhere:** `.pvm` → `versions/<v>` (dir link). Delete the Unix `.pvm/php` file-link variant and `update-alternatives` | Fixes B16; `SymLinkInspector` works unchanged on all OSes |
| 2.3 | **`ILinkManager`**: `createDirLink`, `isLink`, `readTarget`, `remove` — Windows = junction (fallback symlink), Unix = symlink | Pulls link logic out of the three `*_os_manager.dart` files |
| 2.4 | **Merge OS managers**: one `IoOSManager` + injected `PlatformInfo`/`ILinkManager`; remove duplicated Linux/macOS managers | Removes ~270 duplicated lines |
| 2.5 | `Project` takes `IOSManager` (no `Platform.environment`, no `dart:io` statics) | D3 |
| 2.6 | `IInstaller` split: `IReleaseSource` (list/resolve releases) + `IArtifactInstaller` (download → verify → extract → stage → commit). Shared transactional pipeline from 0.5 | `i_release_source.dart` already exists — wire it |
| 2.7 | Composition root: `buildRunner(PlatformInfo, …)` callable from tests; consider dropping `get_it` | D7 |
| 2.8 | CI matrix: `windows-latest`, `ubuntu-latest`, `macos-latest` (unit tests on all, mocks/fakes) | Tests must already pass on Unix thanks to the HAL |

Exit criteria: zero `if (PlatformDetector.isX)` outside factories; full suite green on all three OSes.

### Phase 3: Linux & macOS PHP sources
- Status: Pending
- Decision: **PVM-managed builds in `versions/`**, never system package managers (no `sudo`, no apt/brew side effects).

| # | Task | Notes |
|---|------|-------|
| 3.1 | `StaticPhpReleaseSource`: prebuilt CLI binaries from the static-php-cli project (linux x86_64/aarch64, macOS x86_64/arm64) | Verify hashes; if upstream publishes none, pin hashes in a PVM-maintained manifest signed in CI |
| 3.2 | Optional `SourceBuildInstaller` (`pvm install 8.3 --from-source`): download php.net tarball, **GPG-verify** against php.net release keys, `./configure --prefix=versions/<v>` | Needs build deps; doctor lists missing ones |
| 3.3 | `pvm link <version> <path>`: adopt an existing PHP (apt `ondrej/php`, Homebrew `php@8.3`, MAMP, Laragon, XAMPP on Windows) as a named version | Covers users who already have PHP |
| 3.4 | Remove `LinuxInstaller`, `MacOSInstaller`, `PackageManagerInstaller`, throwing release fetchers | Fixes S6 |
| 3.5 | Extensions & ini: per-version `php.ini` scaffold, `pvm ext list` (read-only first) | Static builds have a fixed extension set — document it |
| 3.6 | Windows: add arm64 builds when php.net publishes them; `--arch` default from host | |

### Phase 4: Shell integration & auto-switching
- Status: Pending
- Problem: on Unix there is no "PATH contains `.pvm` of the cwd" trick; per-project switching needs shims or a shell hook.

| # | Task | Notes |
|---|------|-------|
| 4.1 | **Shims** in `~/.pvm/shims/` (`php`, `composer`, `phpize`, `php-config`; `.cmd` shims on Windows) that `exec` the version resolved local → global | Works in every shell, IDE and cron; recommended default |
| 4.2 | `pvm env --shell bash|zsh|fish|powershell` + optional cd-hook (like `fnm`/`direnv`) for users who prefer PATH rewriting | Optional, after shims |
| 4.3 | Fast resolution path for shims (no full DI boot; target < 15 ms) | Measure in CI |
| 4.4 | Resolution precedence documented and identical everywhere: `PVM_VERSION` env → `.pvmrc` (walk up) → global | Uses `ActiveVersionResolver` |

### Phase 5: `pvm setup` on Unix
- Status: Pending

| # | Task | Notes |
|---|------|-------|
| 5.1 | `UnixEnvironmentConfigurator`: add a marked block (`# >>> pvm >>>`) to `~/.bashrc`, `~/.zshrc`, `~/.config/fish/conf.d/pvm.fish`; idempotent; `--dry-run` shows the diff | Replaces `NoopEnvironmentConfigurator` |
| 5.2 | Default homes: `$XDG_DATA_HOME/pvm` (Linux), `~/Library/Application Support/pvm` or `~/.pvm` (macOS); `PVM_HOME` overrides | The `~/.pvm/versions` legacy guess was already removed in 2.4 |
| 5.3 | `pvm doctor` Unix checks: shims on PATH, shell block present, conflicting system `php` earlier on PATH | |
| 5.4 | `pvm self uninstall` on all platforms (removes PATH/rc entries, links, optionally versions) | |

### Phase 6: Distribution & release → v3.0.0
- Status: Pending

| # | Task |
|---|------|
| 6.1 | Release workflow builds `pvm` for win-x64, win-arm64, linux-x64, linux-arm64, macos-x64, macos-arm64 (`dart compile exe` per runner) |
| 6.2 | `SHA256SUMS` + build provenance attestation; macOS codesign/notarize, Windows Authenticode (optional, later) |
| 6.3 | Install scripts: `install.sh` (curl, verifies checksum) and `install.ps1`; both call `pvm setup` |
| 6.4 | Package channels: Scoop / WinGet manifest, Homebrew tap; `pvm self update` with checksum verification |
| 6.5 | End-to-end tests per OS in CI: install real PHP, `use`, `php -v`, `composer --version`, `exec`, `uninstall` |
| 6.6 | Docs: README per-platform install, migration guide v2 → v3 (Unix `.pvm` layout change), threat model section |

---

## Progress Log

### 2026-11-04
- Plan created from a full source read, security audit and code check of `main` @ `1c6ffb6`.
- Probes confirmed S3, S4, S5, S7 and B9; analyze clean, 503 tests passing.
- Phase 0 implemented on `fix/phase-0-critical`, with regression tests for every task. 530 tests passing, `analyze --fatal-infos` clean, format clean.
- Housekeeping needed to commit at all:
  - `main` failed CI on `dart format`, so a separate format-only commit was added.
  - The pre-commit `outdated`/`pull-up-dependencies` checks blocked every commit, so the lockfile was refreshed and lower bounds raised (no new packages).

- Phase 1 implemented on `feat/phase-1-correctness`. Notes:
  - **1.1:** Dart treats junctions as links (`type`, `target()` and `delete()` were all verified on a real filesystem), so the inspector and uninstall code are unchanged.
  - **1.3:** windows.php.net publishes **no checksums for archived builds** (`archives/sha256sum.txt` returns 404), so older patches are opt-in via `--allow-unverified` and flagged by `doctor --verify`.
  - **1.9:** actions are pinned to the latest releases' commit SHAs (looked up via the GitHub API on 2026-11-04).
- The end-to-end run of the compiled binary against live php.net found two pre-existing bugs, both fixed with regression tests:
  - **B17:** every exit code was 0, because `main`'s return value is ignored.
  - **B18:** `8.4.27-1` was parsed as `8.4.0`.
- Lesson: keep a real-binary smoke test in CI (Phase 6.5).

## Conclusion
_To be filled when v3.0.0 ships._

## Suggestions
- Phase 0 is small (roughly 1–2 focused days) and is worth releasing on its own before any refactor starts.
- Phases 2.1–2.3 are the critical path for everything after them; don't start Phase 3 until 2.8 is green on all OSes.
- Prefer junctions on Windows (1.1). They remove the single biggest onboarding problem (Developer Mode/admin) at the same time.
