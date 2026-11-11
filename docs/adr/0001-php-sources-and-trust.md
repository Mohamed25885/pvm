# 0001. PHP sources, trust and extensions

## Status

Accepted (2026-11, Phase 3).

## Context

PVM was Windows-only and installed from windows.php.net. Linux and macOS need a PHP source that needs no `sudo` and no system package manager. Users also want extensions such as xdebug, and some already have a PHP they want to keep using.

## Decision

- **Q1 Trust.** Verify the download against the release source's published checksum. With none published, refuse unless `--allow-unverified`. The actual SHA-256 is recorded either way.
- **Q2 Sources.** static-php on Linux and macOS, windows.php.net on Windows. The apt and Homebrew installers are gone; a system PHP enters through `pvm link <X.Y> <folder>`.
- **Q3 static-php.** Only the `v3/` tree of dl.static-php.dev.
- **Q5 Default set.** `bulk`.
- **Q6 Linux build.** The prebuilt is fully static musl, so it never loads a `.so`.
- **Q7 Missing patch.** Asking for an unbuilt patch errors and lists the available ones; `8.3` picks the newest.
- **V1 Slots.** One slot per minor, `versions/<X.Y>`. `pvm update X.Y` moves to the newest patch.
- **V2 Display.** `8.5 (8.5.22)`.
- **E1 Extensions need a full folder** (one with `php-config`). A static slot refuses them and names the two routes to one: `pvm install X.Y --from-source --force` or `pvm link`. Building from source is opt-in.
- **E2 Missing tool.** PVM prints the exact platform command, asks the user to run it and re-run, and exits non-zero.
- **E3 No auto-rebuild across minors.** Extensions are per version; switching to a version without one only prints a hint (`xdebug is installed for 8.2 but not 8.3. Run: pvm ext install xdebug`).
- **E4 Extension downloads publish no checksum.** They install without `--allow-unverified`; the file's SHA-256 is recorded and the extension is marked unverified. Running `pvm ext install` is the explicit request.

## Consequences

- Only the newest static-php patch of a minor is installable, because only it has a published `.sha256`; older ones are never offered. `--allow-unverified` covers archived Windows releases and php.net tarballs without a checksum.
- Every redirect hop of a download must be https.
- `install --force` reinstalls the same patch, or replaces a slot of another kind at any patch (a kind change is a replacement, R30). A newer patch of the same kind is `pvm update X.Y`.
- `pvm ext install` into a linked, writable folder writes into the folder PHP's own scan dir, not a PVM `conf.d`.
- On Windows, a slot's extensions are enabled in a PVM-managed block of its own `php.ini`, so php.exe loads them however it is started.
- On Windows, a failing probe warns instead of blocking the install.
- A source build needs a compiler toolchain; the error message names what is missing.
- Known limitation: `PHP_INI_SCAN_DIR` set on a PVM-started static PHP is inherited by that PHP's own children (a script's `exec('php ...')`, Composer's subprocesses), which then read the slot's `conf.d` too. The user's shell never sees it.
