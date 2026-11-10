# Handoff: how PVM should get PHP on Linux and macOS

Written 2026-11-10. For the next agent continuing roadmap task 3.1 (`StaticPhpReleaseSource`) in [cross-platform-roadmap.md](cross-platform-roadmap.md).

## Your job

Research, against primary sources, how open-source PHP version managers on **Linux and macOS** obtain PHP binaries and how their users add **PECL extensions**. The output decides whether PVM ships static-php prebuilt binaries on Linux/macOS, or something else.

Research question:

> How do open-source PHP version managers on Linux and macOS get PHP binaries, and how do users add PECL extensions in each? Compare build-from-source, package-manager, and prebuilt/static approaches on: install speed, required system dependencies, extension support (can `pecl install` + `extension=foo.so` work?), several versions side by side without sudo, and checksum/signature verification of what they download.

Candidates to check (from memory, **unverified**; confirm each and add any missed):

- Build from source: phpbrew, phpenv + php-build, asdf-php, mise (PHP plugin/backend)
- Package manager: Homebrew `shivammathur/php` tap, Ubuntu `ondrej/php` PPA + `update-alternatives`
- Prebuilt/static: Laravel `php.new` and Herd / Herd Lite (believed to use static-php-cli: verify), any others

Specifically answer:

1. Does any tool ship prebuilt binaries that *can* load PECL `.so` extensions on Linux? How?
2. Do the static-php-based tools (if any) document the no-extensions limit, and how do they work around it?
3. Can static-php's **`gnu-bulk`** (glibc) Linux prebuilt or its **macOS** prebuilt load a PECL-built `.so`? Upstream docs only show this for self-builds (see below). A concrete test on a real binary beats any doc.

Save findings, with a citation per claim, to `reports/` (matching the existing report) or `research_notes/<title>/`.

## What is already established (read these first)

- [reports/Static PHP CLI release artifacts.md](../../reports/Static%20PHP%20CLI%20release%20artifacts.md): the cited report on what static-php-cli publishes. Notes behind it are in `research_notes/Static PHP CLI release artifacts/`.
- Key facts:
  - PHP binaries exist only on `dl.static-php.dev/v3/php-bin/<set>/`. GitHub Releases carry only the `spc` builder tool.
  - Sets: `minimal` (7 ext), `common` (37), `bulk` (56), plus `gnu-bulk` (glibc 2.17, Linux only). Linux and macOS come in x86_64/aarch64; Windows is x64 `spc-min`/`spc-max`. PHP 8.2–8.5.
  - Each archive has a `.sha256` file next to it, only for the newest patch of each minor version and only since 2026-10-23, on the same host. There are no signatures and no attestations for the PHP binaries.
  - Built by the `static-php/hosted` repo's GitHub Actions every 3 days, from a moving `v3` branch.
  - Send an explicit User-Agent: Python's default got HTTP 403.
- Extension loading, from https://static-php.dev/en/faq/:
  - Purely static (`-all-static`) builds "cannot load dynamic libraries, so new extensions cannot be added".
  - glibc builds can load `.so` extensions with the same ABI, but this is shown only for a self-build (`SPC_TARGET=native-native-gnu.2.17`).
  - macOS supports shared extensions via `--build-shared`, also shown only for a self-build.
  - Windows: "no way to load dynamic extensions with static-php".
  - Nothing in the docs promises `.so` loading for the downloadable prebuilts on any platform.

## Decisions already made (do not reopen without new facts)

From a `/grill-with-docs` session with the user on 2026-11-10:

| # | Decision |
|---|----------|
| Q1 | Trust rule: verify against the release source's published checksum, even though it is on the same host. That is the same rule as the existing windows.php.net path (`lib/src/services/installation/artifact_installer.dart`). No published checksum → refuse unless `--allow-unverified`, and record the actual hash either way. A PVM-signed pinned-hash manifest is a possible later upgrade, not now. |
| Q2 | static-php only on Linux and macOS. Windows stays on windows.php.net. Remove the apt and Homebrew installers (roadmap 3.4). |
| Q3 | Use only the `v3/` tree. Never the legacy `/static-php-cli/` tree, which has no checksums, is frozen since July 2026, and only adds EOL PHP 8.0/8.1. |
| Q4 | Land the PRs in stack order: merge Mohamed25885/pvm#4 (`chore/guardrails` → `feat/phase-2-foundations`), then mark Mohamed25885/pvm#3 ready and merge it to `main`, then do Phase 3 work on a new `feat/phase-3-static-php` branch. **Not done yet.** |
| Q7 | Asking for a patch static-php never built (e.g. `pvm install 8.3.34`) → error listing the available versions. `pvm install 8.3` picks the newest patch that exists. |

## Still open (what your research unblocks)

- **Q5: extension bundle.** The proposal was `bulk` by default, because a static binary can't add extensions later.
- **Q6: Linux build type.** The proposal was fully static musl (runs on any Linux, including Alpine) over `gnu-bulk`.
- Fallback for users needing custom extensions: roadmap 3.2 (`--from-source`) or 3.3 (`pvm link` to an apt/Homebrew PHP).

The user pushed back: other PHP version managers never mention a "no extensions" limit. The suspected reason is that they compile from source or use package-manager PHP rather than static binaries, but that is a hypothesis to test.

**If research shows a better Linux/macOS source than static-php** (or that `gnu-bulk`/macOS prebuilts load PECL extensions fine), bring it back to the user as a new option for Q2/Q5/Q6. Don't change the decision yourself.

## After the research

Resume the grilling with the user on Q5/Q6, then write:

- `docs/adr/0001-<slug>.md` (no `docs/adr/` exists yet), recording the trust rule and the source choice;
- an edit to roadmap task 3.1, whose current note ("if upstream publishes none, pin hashes in a PVM-maintained manifest") is superseded by Q1.

`GLOSSARY.md` at the repo root already defines *release source*, *published checksum*, *verified install* and *unverified install*. Use those terms.

## Repo state at handoff

- On branch `chore/guardrails`. `GLOSSARY.md`, `reports/`, `research_notes/` and this file are **untracked**; per Q4 they belong on the Phase 3 branch, not in the guardrails PR.
- SDK: `fvm dart …` (Flutter 3.44.2 / Dart 3.12.2). Prefix shell commands with `rtk` (see `CLAUDE.md`).
