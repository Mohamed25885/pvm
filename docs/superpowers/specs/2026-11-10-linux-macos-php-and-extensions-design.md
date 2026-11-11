# Per-version PHP folders and `pvm ext install`: design

Date: 2026-11-10. Brainstormed with the user. It continues the handoff `.agents/plans/handoff-linux-macos-php-source.md` and rests on two reports:
- `reports/PHP sources and extensions per platform.md`, the latest, which recommends the folder model;
- `reports/PHP source and extension strategy for Linux and macOS.md`.

Terms follow `GLOSSARY.md`: *release source*, *published checksum*, *verified install*, *unverified install*.

## Intent

PHP is hard to set up. PVM exists to make it simple. A user should get a working PHP in seconds on Windows, Linux and macOS. When they need more, such as xdebug, they should get it with one PVM command.

**PVM is a thin layer over the platform's tools, not a bundle.** It finds what is already installed (C compiler, make, autoconf, `phpize`, `php-config`, PIE), drives those tools, and uses whatever tricks get the job done. It never ships or wraps its own toolchain, and it never runs sudo. *(The user's words: "a proxy over tools on the platform, not a bloat that encapsulates tools.")*

**Every PHP version is a folder** (the user's Plesk-style idea). A slot holds `bin/php` (`php.exe` on Windows), plus `phpize` and `php-config` when the build has them. PVM learns what a folder can do by probing it, and every command acts on that probe, never on how the folder was made. A static-php download, a PVM source build, a Windows zip and a folder the user brings are all the same kind of thing.

## Goals

1. `pvm install 8.4` is fast everywhere:
   - **Linux/macOS:** a static-php `bulk` prebuilt.
   - **Windows:** a windows.php.net zip.
2. `pvm install 8.4 --from-source` gives Linux/macOS users a full folder that can take any extension.
3. `pvm link 8.4 <folder>` adopts a PHP folder the user already has (Plesk, Remi, cPanel, Homebrew, pkgx, a self-build, Laragon or XAMPP).
4. `pvm ext install <ext>` adds a PECL extension to **one** version, on all three OSes. Everyday example: **xdebug**. Advanced example: **grpc** (a long C++ compile).
5. Extensions belong to one version. xdebug installed for 8.2 is absent from 8.3, and still there after switching back to 8.2.
6. One slot per minor version. A patch is an update, not an extra install.
7. Versions display as `8.5 (8.5.22)`, the way `composer.json` and `composer.lock` relate.

## Non-goals

- Carrying extensions across minor versions automatically. PVM shows a hint instead. *(user)*
- Running sudo, apt, brew, `xcode-select` or any other privileged install. PVM prints the exact command and stops. *(user)*
- Installing PHP itself from apt or Homebrew. Q2 stands: roadmap 3.4 removes those installers. Their PHPs come in through `pvm link`.
- Rebuilding a static slot behind the user's back. *(user: refusing one extension is better than a surprise rebuild)*
- Loading `.so` files into static-php prebuilts. That path is unproven, and the folder model makes it unnecessary.
- Source builds on Windows.

## Anti-goals (failure even if it "works")

- PVM silently changing system state: running sudo, installing packages, writing into a system extension dir or a shared ini.
- An extension installed for one version leaking into another, whether through files or through environment variables that child processes inherit.
- A failed install, update or extension build leaving a slot half-changed.
- Re-implementing what PIE, phpize and make already do.

## Decisions

| # | Decision | Source |
|---|---|---|
| Q1 | Trust rule: verify against the release source's published checksum. With no checksum, refuse unless `--allow-unverified`. Record the actual hash either way. | handoff |
| Q2 | static-php on Linux/macOS, windows.php.net on Windows, apt and Homebrew installers removed. System PHPs enter through `pvm link`. | handoff, refined here |
| Q3 | Only the `v3/` tree of dl.static-php.dev. | handoff |
| Q5 | Default set is `bulk`. PDO sqlite works in it (tested on Linux). | WSL test |
| Q6 | The Linux prebuilt is fully static musl. Extensions always need a full folder, so the prebuilt never has to load a `.so`. | my call |
| Q7 | Asking for an unbuilt patch errors and lists the available ones. `8.3` picks the newest. | handoff |
| E1 | Extensions need a full folder, one that has `php-config`. A static slot refuses them and names the two routes to a full folder. Building from source is opt-in only. | user (replaces the earlier "rebuild in place") |
| E2 | A missing tool means PVM prints the exact platform command, asks the user to run it and re-run, and exits non-zero. | user |
| E3 | No auto-rebuild across minors, only a hint. | user |
| E4 | Extension downloads (PECL tarballs, PECL Windows DLLs, PIE assets) publish no checksum. They install without `--allow-unverified`. PVM records each file's SHA-256 and marks the extension *unverified* in the record. Running `pvm ext install` is itself the user's explicit request. | user |
| V1 | One slot per minor. `pvm update X.Y` moves to the newest patch. | user |
| V2 | Display format `8.5 (8.5.22)`. | user |

## The folder and its probe

**Layout.** `versions/<X.Y>/` holds the PHP tree. The linked kind is the exception: for it, `versions/<X.Y>` is a link to the user's folder. Each slot has a record, `.pvm-install.json`, which extends today's `InstallRecord`.

| Field | Meaning |
|---|---|
| `kind` | `static`, `source`, `windows-zip` or `linked` |
| `version` | Full patch, e.g. `8.4.27` |
| `zts`, `arch`, `apiNo` | Read from the folder's own `php` |
| `phpConfig` | Absolute path, or null |
| `prefix` | `php-config --prefix`, Unix only |
| `extensionDir` | As PHP reports it |
| `writable` | Can PVM write `extensionDir` and the slot's ini dir without sudo? |
| `sourceUrl`, `archiveSha256`, `verified`, `files` | As today |
| `extensions` | User-added extensions: name, version, file, sha256, verified flag |

**Probe.** PVM runs the probe once, on `install`, `update` and `link`, and on a `prefix` mismatch (see below). It never runs per command, so commands and shims stay fast. The probe asks the folder's own `php` for `PHP_VERSION`, `PHP_ZTS`, the arch, `PHP_EXTENSION_DIR`, the loaded ini and the scan dir. On Unix it also looks for `phpize` and `php-config` next to `php`, under either name form (`php-config` or `php-config8.4`), and checks that `php-config --prefix` matches the folder. On Windows it tells NTS from TS by `php8.dll` versus `php8ts.dll`.

**Staging rule.** `install`, `update`, `--from-source` and `ext install` all build or unpack into `versions/.staging-<X.Y>/`. The result is swapped into place only after it succeeds and passes the probe or load check. If anything fails, the staging dir is removed and the old slot is untouched. On Windows, PVM refuses to swap while the slot's `php.exe` or an extension DLL is in use, says which process holds it, and asks the user to stop it and re-run.

**Ini.** Each PVM-owned slot has its own `etc/php.ini` and `etc/conf.d/`. User-added extensions get one ini file each (`conf.d/50-xdebug.ini`), and disabling one renames its file to `.ini.disabled`. PVM passes the slot's ini **only to the PHP process it starts itself**: `-c` and `PHP_INI_SCAN_DIR` go on that child process, never into the environment that the user's shell or Composer's child PHPs inherit. A source-built slot is configured with `--with-config-file-path=<slot>/etc` and `--with-config-file-scan-dir=<slot>/etc/conf.d`, so it finds its ini even when run directly. A static slot run directly, outside PVM, uses the binary's compiled-in defaults until the Phase 4 shims exist. That is acceptable, because a static slot never carries user-added extensions.

## Commands

### `pvm install <X.Y[.Z]> [--from-source]`

1. **Default source per platform:**
   - Linux/macOS: the static-php `bulk` CLI archive for the host arch. PVM verifies it against the `.sha256` sidecar, and the slot's kind is `static`.
   - Windows: the windows.php.net zip, verified as today, kind `windows-zip`.
2. **`--from-source`** (Linux/macOS only):
   - PVM downloads the php.net tarball and verifies it against php.net's published sha256; it adds the GPG check if keys are available.
   - It checks the build tools and `-dev` libraries first (E2).
   - It builds with `--prefix=<PVM_HOME>/versions/<X.Y>` and the ini paths above. The configure flags cover the bundled `bulk`-equivalent set: intl, gd, zip, bcmath, sodium, soap, pgsql, pdo_*, opcache, and so on. The kind is `source`.
   - Measured on Linux, about 5 minutes on 8 cores, needing about 20 build packages.
   - PVM says this before starting.
3. **Slot already filled:** `pvm install 8.2.29` when 8.2 exists installs nothing. It prints `8.2 is installed (8.2.28). Run: pvm update 8.2` and exits non-zero.

### `pvm link <X.Y> <folder>`

PVM probes the folder and rejects it if `php` is missing or its version isn't `X.Y`. On success, the slot becomes a link to the folder with kind `linked`. PVM never writes inside a linked folder. `pvm uninstall` on a linked slot removes only the link.

### `pvm update <X.Y>`

| Kind | What happens |
|---|---|
| `static` / `windows-zip` | Download the newest patch into staging, then swap |
| `source` | Rebuild the newest patch in staging, then swap. User-added extensions are rebuilt against the new build in staging; any that fail are named, with the command to retry |
| `linked` | Refused, because the folder isn't PVM's to update |

Within a minor version the extension ABI is stable, so a Windows DLL carries over unchanged. Every carried extension must pass the load check before the swap happens.

### `pvm ext install <ext> [--version=X.Y]`

1. **Target.** With no `--version`, PVM uses the active version: local first, then global, the same `ActiveVersionResolver` as `pvm php`. With neither, it errors.
2. **Already present.** If `php -m` already lists the extension, PVM says so and stops.
3. **Route by probe:**

| Slot | Route |
|---|---|
| `windows-zip` | Fetch the DLL zip matching ABI, NTS/TS and VS version: first the extension's PIE/GitHub release asset, then the PECL DLL listing. A 404 means "not built for this PHP", and PVM says so. Dependency DLLs go next to `php.exe` |
| `source`, or `linked` + writable + has `php-config` | Fetch the PECL tarball, then run the slot's `phpize`, `./configure --with-php-config=<slot php-config>` and `make` in staging. If `pie` is on PATH and the extension is a PIE package, PVM may use `pie install --with-php-config=…` instead |
| `linked`, not writable (Plesk, Remi, cPanel, ondrej) | Print that system's own command (e.g. `sudo apt install php8.4-xdebug`, `/opt/plesk/php/8.4/bin/pecl install xdebug`) and stop (E2) |
| `static` | Refuse: `xdebug isn't in this build. Run: pvm install 8.4 --from-source --force, or pvm link 8.4 <folder>`. Exit non-zero (E1) |

4. **Before building.** PVM checks for cc/clang, make, autoconf, pkg-config and the extension's known system libraries (E2). For grpc it adds a C++ compiler and warns that the build takes a long time.
5. **Prefix guard.** If `php-config --prefix` no longer matches the slot, because `PVM_HOME` moved, PVM refuses and asks the user to reinstall that slot. Otherwise `phpize` would write into the old path.
6. **Enable and check.** PVM writes the extension's ini, using `zend_extension` when the binary exports `zend_extension_entry` and `extension` otherwise. It then runs the slot's `php -m` to confirm the extension loads. On failure it rolls back both the ini and the file.
7. **Record.** It adds the extension to the slot record with its SHA-256, marked unverified (E4).

### Hint on switching (E3)

When `pvm use`, `pvm global` or `pvm current` resolves a version, PVM compares that slot's `extensions` with the other slots' records. For each extension missing here, it prints one line, such as `xdebug is installed for 8.2 but not 8.3. Run: pvm ext install xdebug`. The line is informational, with zero exit and no prompt.

### Display (V2)

Every place PVM shows an installed version (`list`, `current`, `doctor`, `use`) uses `<X.Y> (<X.Y.Z>)`, for example `8.5 (8.5.22)`. Users type the short form.

## Migration from full-patch slots

Today slots are named by full patch (`versions/8.2.28`). On the first run of the new version, PVM:
1. Renames each slot to its minor (`versions/8.2`).
2. Re-points every link that targets it in the same step: the global link, the project `.pvm` links PVM can find, and `.pvmrc` values holding a full patch, which now map to their minor.
3. Refuses if two patches of the same minor exist. It names both and asks the user to `pvm uninstall` one, so it never picks silently.

## Constraints

- Dart CLI. The composition root is `lib/src/app.dart`. Platform choice happens only in factories (Phase 2 exit criterion).
- Every PHP download follows Q1. Extension downloads follow E4.
- Tests stay Unix-portable. The probe, router, staging and migration get unit tests with fake folders.
- Work goes on `feat/phase-3-static-php`, after the PR stack in Q4. Not on `chore/guardrails`.

## Proven so far, and what's left

Linux checks ran on WSL2 (Ubuntu 22.04, 8 cores) on 2026-11-10. WSL2 runs a real Linux kernel and glibc, so it is a valid Linux test bed. It can't cover macOS. Keep work under `~`, not `/mnt/c`, and expect occasional DNS failures, which need retries.

1. **Done on Linux.** PDO sqlite in static-php `bulk`, `common` and `gnu-bulk` 8.4.27:
   - Each archive matched its `.sha256`.
   - `new PDO('sqlite::memory:')` works in all three.
   - In `bulk`, the sqlite and pgsql PDO drivers come from swoole and behave normally.
2. **Done on Linux.** A php.net 8.4.27 source build into a user-owned prefix:
   - The tarball sha256 matched php.net's JSON.
   - Configure took 71 s and make 235 s, about 5 min 14 s in total. The result is 142 MB.
   - It produced `phpize` and `php-config`, and no `pecl`.
   - It needed about 20 build packages; 22 were missing on this machine.
3. **To do:**
   - `pvm ext install xdebug` end to end on Linux and macOS.
   - The probe on a real ondrej, Plesk or Remi, and Homebrew folder.
   - The macOS repeats of 1 and 2.
   - grpc once, only to measure its build time.

## Left to the builder

- The exact configure flags per distro and macOS, and the system-library map behind the E2 messages.
- How PVM maps a short name to a PIE package (`xdebug` → `xdebug/xdebug`), and when it tries PIE versus the plain tarball.
- Command wording and exit-code numbers. Each failure class gets its own exit code.
- ADR `docs/adr/0001-<slug>.md`, covering the trust rule, E4 and the source choice. Roadmap updates:
  - 3.1: the "pin hashes" note is superseded by Q1.
  - 3.2: `--from-source` is in this phase.
  - 3.3: `pvm link` is in this phase.
  - 3.5: per-slot ini and `ext install`.
- A `GLOSSARY.md` line saying that `pvm ext install` counts as the explicit request for an unverified install.
