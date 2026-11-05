# PVM Security Audit — 2026-11-04

**Scope:** `main` @ `1c6ffb6` (v2.0.0), all of `lib/`, `pvm.dart`, CI workflows.
**Method:** full manual read of the source + targeted probes (Dart scripts run against the real `package:archive`, `package:path` and `Project` code). Static analysis clean, 503 tests passing at time of audit.

Severity scale: **High** = data loss or code execution reachable in normal use · **Medium** = exploitable under realistic but non-default conditions · **Low** = hardening / defence in depth.

## Summary

| ID | Severity | Area | Title | Status |
|----|----------|------|-------|--------|
| S1 | High | `pvm setup` | `setx` truncates the user `PATH` to 1024 chars | Confirmed (documented `setx` behaviour) |
| S2 | High | Symlinks | `createSymLink` recursively deletes a real directory at the link slot | Confirmed by code |
| S3 | High | `pvm use` | Running in `%USERPROFILE%` overwrites the global link and writes `.pvmrc`/`.gitignore` into home | Confirmed by probe |
| S4 | Medium | `pvm install` | Zip-slip guard uses a string prefix check (`8.3.1` ⊂ `8.3.10`) | Confirmed by probe |
| S5 | Medium | `pvm composer` / `exec` | Empty `PATH` segment makes Composer resolve from the current directory (binary planting) | Confirmed by probe |
| S6 | Medium | Linux/macOS install | `isInstalled` treats any same-major PHP as installed; `sudo apt-get` path | Confirmed by code |
| S7 | Low | Downloads | Host allow-list uses `endsWith` (`evilwindows.php.net` passes) | Confirmed by probe |
| S8 | Low | Downloads | Checksum comes from the same origin as the binary; no signature check | Design note |
| S9 | Low | Downloads | Stale ZIP in `versions/` is reused without re-download | Confirmed by code |
| S10 | Low | Process | Unresolved commands fall through to `CreateProcess` search order (cwd first) | Confirmed by code |
| S11 | Low | Elevation | Prompt promises elevation that can never happen | Confirmed by code |
| S12 | Low | Supply chain | CI uses `actions/checkout@v3`, actions not pinned by SHA | Confirmed |

---

## Findings

### S1 — `setx` truncates PATH (High)
`lib/src/managers/windows_environment_configurator.dart:38,65` writes the merged user `Path` with `setx Path <value>`. `setx` silently truncates values longer than 1024 characters, and it rewrites the value as `REG_SZ`, which breaks `%VAR%` expansion in entries that relied on `REG_EXPAND_SZ`. A developer with a long user PATH loses entries permanently when they run `pvm setup`.

**Fix:** write `HKCU\Environment\Path` directly (`reg add HKCU\Environment /v Path /t REG_EXPAND_SZ /d ... /f`, or the Win32 registry API via `win32` FFI). Preserve the original value type. Back up the old value to `%PVM_HOME%\path.backup` before writing. Broadcast `WM_SETTINGCHANGE` afterwards. Refuse to write if the result would be shorter than the original.

### S2 — Recursive delete at the link slot (High)
`lib/src/managers/windows_os_manager.dart:66-78`: if `<target>\.pvm` exists as a **real directory**, it is removed with `Directory(to).delete(recursive: true)`, without asking. Errors are swallowed. Both slots are affected:
- `%USERPROFILE%\.pvm` is a common name, used by other tools and by PVM's own legacy Unix layout.
- A project folder that happens to contain a `.pvm` directory.

`GitIgnoreService.ensurePvmSymlinkExists` (dead code, see the code review) has the same pattern.

**Fix:** delete only when the slot is a link (or a junction). If it's a real directory or file, abort with a clear error ("`.pvm` exists and is not a PVM link; move it away"). Don't swallow errors.

### S3 — `pvm use` in the home directory clobbers the global link (High)
When no `.pvmrc` is found, `Project.findFromPath` (`lib/src/domain/project.dart:73-105`) skips the home `.pvm` marker but then **falls back to `startPath`**. Run `pvm use 8.3` from `%USERPROFILE%` and:
- `WindowsVersionActivator.activateLocal` replaces `%USERPROFILE%\.pvm`, which is the global link.
- `.pvmrc` and `.gitignore` are written into the home directory.

Verified on this machine: `Project.findFromPath('C:\Users\Samy')` returns `C:\Users\Samy`, whose `.pvm` is the live global link.

**Fix:** if the resolved root equals the home directory (or a filesystem root), refuse `use` with a hint ("run inside a project folder or create `.pvmrc` first"). Read home via `IOSManager.getHomeDirectory()`, not `Platform.environment`.

### S4 — Zip-slip prefix check (Medium)
`lib/src/managers/windows_installer.dart:132`: `normalizedPath.startsWith(destCanonical)`. Probe result: with `dest = C:\pvm\versions\8.3.1`, the entry `..\8.3.10\php.exe` normalizes to `C:\pvm\versions\8.3.10\php.exe` and **passes**. `package:archive` keeps the `../` name verbatim (also probed). A crafted archive could therefore plant or replace files in a *sibling* version directory, for example swapping another version's `php.exe`. It's reachable only if the ZIP's origin is compromised, which is why it's Medium and not High. The write also uses the un-normalized `fullPath`.

**Fix:** `if (!p.isWithin(dest, normalized)) throw` (abort, don't skip). Write to the normalized path. Reject absolute names, drive letters, and symlink entries.

### S5 — Composer resolved from the current directory (Medium)
`lib/src/core/composer_locator.dart:22-31` splits `PATH` without dropping empty segments. A trailing `;` is common on Windows. Probe: `C:\a;C:\b;` yields the candidate `composer.phar` (relative), which resolves against the cwd, i.e. the project root. If you clone a hostile repo containing `composer.bat` and `composer.phar` and run `pvm composer …` (or `pvm exec -- composer …`), the repo's phar runs. `IOProcessManager._findCommandInPath` already filters empty segments; the locator doesn't.

**Fix:** skip empty and relative PATH segments. Only accept absolute directories.

### S6 — Unix installer trust and logic (Medium)
`lib/src/managers/package_manager_installer.dart:33-37`: `_matchesRequestedVersion` returns true for any version with the same **major** (8.1 "satisfies" 8.4), so installs are silently skipped. `LinuxInstaller` runs `sudo apt-get install -y` when `useSudo` is set. That's a privileged system mutation from a version manager, and it installs outside `versions/`. This becomes moot once the Unix install path is redesigned (see the roadmap), but it must not ship as is.

### S7 — Host allow-list suffix match (Low)
`windows_installer.dart:220`: `uri.host.endsWith(d)`. The probe shows that `evilwindows.php.net` passes. Only php.net could actually serve that host, so the risk is low, but the check is wrong. The scheme isn't checked here either.

**Fix:** `uri.scheme == 'https' && (host == d || host.endsWith('.$d'))`.

### S8 — Same-origin checksum (Low, design)
The SHA-256 values come from `releases.json` on `downloads.php.net` over TLS, and so does the ZIP. The checksum protects against corruption, not against a compromised origin. php.net publishes GPG-signed release manifests for source tarballs, but not for the Windows builds.

**Recommendation:**
- Keep TLS plus SHA-256.
- Record the checksum of every installed build in `versions/<v>/.pvm-install.json`, so tampering after install is detectable (`pvm doctor --verify`).
- Document the trust model in the README.

### S9 — Stale download reuse (Low)
`downloadPhp` returns an existing `versions/<file>.zip` without validating it. The ZIP lives in `versions/`, which may be writable by others when it's located under `C:\Program Files` with relaxed ACLs. SHA verification still runs afterwards, so this is mostly a reliability issue.

**Fix:** download to a temp file in a PVM-owned temp dir and atomically rename into place.

### S10 — CreateProcess search order (Low)
`IOProcessManager.resolveSystemCommand` returns the bare command when PATH lookup fails. Windows `CreateProcess` then searches the application directory and the **current directory** before PATH. **Fix:** fail with "command not found" instead of passing the bare name through.

### S11 — Misleading elevation prompt (Low)
`PrivilegeEscalationService` asks "Elevate and retry?", but `WindowsPrivilegeEscalator.requestElevation()` always returns `false`. Not exploitable, but it teaches users to approve elevation prompts that do nothing. It's fixed for real by switching local/global links to **directory junctions**, which need no privilege (see the roadmap, Phase 2).

### S12 — CI supply chain (Low)
`.github/workflows/ci.yml` uses `actions/checkout@v3` and tag-pinned actions. **Fix:**
- Pin actions by commit SHA and update to `checkout@v4`.
- Add `permissions: contents: read`.
- Keep the OSV workflow.
- Add release-artifact checksums and build provenance (`actions/attest-build-provenance`).

## What is already done well
- `PhpVersion.parse` with an anchored regex is used as an input gate before building paths, which closes `..\` injection through version arguments.
- HTTPS-only base URLs, SHA-256 verification on install, and verification failure aborts the install.
- `pvm setup` has `--dry-run` and confirmation, and env writes go through an interface that can be mocked.
- Processes are spawned with argument arrays (`runInShell: false`), with no string-built shell commands.
- Policy and adversarial test suites exist, and OSV scanning runs on PRs.
