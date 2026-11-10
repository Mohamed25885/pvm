# Per-version PHP folders and `pvm ext install`: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PHP on Linux/macOS through static-php, `--from-source` and `pvm link`; one slot per minor version; and `pvm ext install` on all three OSes, driven by a probe of each version folder.

**Architecture:** Every slot `versions/<X.Y>` is a folder (or a link to one) described by an extended `InstallRecord`. A `FolderProbe` fills the record on install, update and link. Commands read the record and never re-probe. Every change to a slot goes through staging plus an atomic swap, generalised from today's `ArtifactInstaller`. `pvm ext install` routes on the slot's `kind`, whether it has a `phpConfig` and whether it is `writable`.

**Tech stack:** Dart 3.12 (FVM Flutter 3.44.2), `args`, `path`, `http`, `archive`, `crypto`, `package:test`.

**Spec:** `docs/superpowers/specs/2026-11-10-linux-macos-php-and-extensions-design.md`

## Global constraints

- Run `rtk fvm dart analyze` and `rtk fvm dart test` before every commit. The pre-commit hook runs the tests.
- Prefix shell commands with `rtk`.
- Platform choice happens only in factories / `PvmDependencies.forHost`. `test/policy/no_host_platform_checks_test.dart` must stay green.
- Tests must be Unix-portable. Use fakes (`FakeOSManager`, `FakeProcessManager`, temp dirs), never the host's real PHP.
- PVM never runs `sudo` and never installs system packages. A missing tool prints the exact command and exits non-zero.
- PHP downloads follow Q1: verify against the published checksum, or refuse unless `--allow-unverified`, and always record the hash. Extension downloads follow E4: no flag needed, record the SHA-256, mark `verified: false`.
- static-php URLs come from `https://dl.static-php.dev/v3/php-bin/bulk/` only. Send `User-Agent: pvm/<version> (+https://github.com/Mohamed25885/pvm)`.
- Display installed versions as `8.5 (8.5.22)`.
- The everyday test extension is `xdebug`. Use `grpc` only where the spec calls it advanced.
- Write the slot's ini only into a PVM-started child process's `-c` / `PHP_INI_SCAN_DIR`, never into the environment the user's shell or Composer's children inherit.

## Review focus

1. **Link targets that still use the old full-patch name** (`versions/8.2.28`), from a project PVM's migration couldn't find. `pvm current` in that project should say the link is stale and print `pvm use 8.2`, not crash. *Test in Task 2.*
2. **A slot whose `php` binary was deleted or replaced after install.** `ext install` should fail with "slot broken, reinstall", not build against a missing `php-config`. *Test in Task 12.*
3. **`--version=8.2` naming a slot that doesn't exist.** `ext install` exits with `versionNotFound` (3) and lists the installed slots. *Test in Task 13.*
4. **The network drops halfway through a static-php download.** The old slot stays intact, and there are no `.staging-*` leftovers once the next run starts. *Test in Task 6.*
5. **An extension name containing path characters** (`../x`, `a/b`). Reject it before any URL or path is built. *Test in Task 13.*

## Order and PRs

| PR | Tasks | Ships |
|---|---|---|
| A | 0–4 | Minor slots, migration, display, extended record, probe. No new sources |
| B | 5–8 | static-php on Linux/macOS, apt/brew installers removed, `--from-source` |
| C | 9–10 | `pvm link`, per-slot ini |
| D | 11–15 | `pvm ext install`, update, hint, docs |

---

### Task 0: Branch and land the design

**Files:** none (git only).

- [ ] **Step 1:** Confirm decision Q4 is done: Mohamed25885/pvm#4 is merged into `feat/phase-2-foundations`, and Mohamed25885/pvm#3 is merged into `main`. Run `rtk gh pr view 3` and `rtk gh pr view 4`. Expected: both `MERGED`. If not, stop and ask the user.
- [ ] **Step 2:** `rtk git switch main && rtk git pull && rtk git switch -c feat/phase-3-static-php`
- [ ] **Step 3:** Commit the design inputs:
  ```bash
  rtk git add GLOSSARY.md reports research_notes .agents/plans/handoff-linux-macos-php-source.md docs/superpowers
  rtk git commit -m "docs: per-version folder design, research and plan"
  ```

### Task 1: Extend `InstallRecord`

**Files:**
- Modify: `lib/src/domain/install_record.dart`
- Test: `test/domain/install_record_test.dart` (create)

**Interfaces:**
- Produces:
  - `enum SlotKind { static, source, windowsZip, linked }`
  - `class ExtensionEntry { String name; String version; String file; String sha256; bool verified; }` with `toJson`/`fromJson`
  - `InstallRecord`, `schemaVersion = 2`, new fields:
    - `SlotKind kind`
    - `bool zts`
    - `String arch`
    - `String apiNo`
    - `String? phpConfig`
    - `String? prefix`
    - `String extensionDir`
    - `bool writable`
    - `String? vsVersion`
    - `List<ExtensionEntry> extensions`
  - `InstallRecord copyWith({...})`
  - `static Future<InstallRecord?> readFrom(String slotDir)`, if it doesn't exist yet. Check the file first and reuse what's there.

- [ ] **Step 1: Write the failing tests.**
  ```dart
  test('v1 record reads as windowsZip with defaults', () {
    final r = InstallRecord.fromJson({'schema': 1, 'version': '8.3.14', 'sourceUrl': 'u', 'archiveSha256': 'a', 'verified': true, 'installedAt': '2026-01-01T00:00:00.000Z', 'files': {}});
    expect(r.kind, SlotKind.windowsZip);
    expect(r.extensions, isEmpty);
    expect(r.phpConfig, isNull);
  });
  test('v2 round-trips every field', () {
    final r = sampleRecord(kind: SlotKind.source, phpConfig: '/v/8.4/bin/php-config',
        extensions: [ExtensionEntry(name: 'xdebug', version: '3.5.3', file: 'xdebug.so', sha256: 'h', verified: false)]);
    expect(InstallRecord.fromJson(jsonDecode(jsonEncode(r.toJson()))), equals(r));
  });
  ```
  Give `InstallRecord` and `ExtensionEntry` value equality, which the round-trip test needs.
- [ ] **Step 2:** Run `rtk fvm dart test test/domain/install_record_test.dart`. Expected: FAIL (the `SlotKind` type is undefined).
- [ ] **Step 3:** Implement. Missing v1 fields default to `kind: windowsZip`, `zts: false`, `arch: 'x64'`, `apiNo: ''`, `extensionDir: '<slot>/ext'` (computed in `readFrom`), `writable: true`, `extensions: []`.
- [ ] **Step 4:** Run the test file, then the full suite. Expected: PASS. Existing installer tests still pass.
- [ ] **Step 5:** Commit: `feat: install record v2 (slot kind, probe fields, extensions)`.

### Task 2: One slot per minor, with migration

**Files:**
- Create: `lib/src/services/slot_migration.dart`
- Modify:
  - `lib/src/domain/version_registry.dart`: slot names are `X.Y`, and the full patch comes from the record.
  - `lib/src/domain/installed_version_resolver.dart`: one slot per minor, so `AmbiguousInstalledVersion` is never produced for migrated slots. Keep the type for the migration's refusal path.
  - `lib/src/app.dart`: run the migration once before dispatching a command.
- Test: `test/services/slot_migration_test.dart`, plus updates to `test/domain/version_registry_test.dart` and `test/domain/installed_version_resolver_test.dart`.

**Interfaces:**
- Produces:
  - `extension SlotName on PhpVersion { String get slot; }` (returns `'$major.$minor'`)
  - `VersionRegistry.getVersionPath(PhpVersion v)`, which now returns `versions/<v.slot>`
  - `Future<List<InstalledSlot>> VersionRegistry.installedSlots()`, where `class InstalledSlot { PhpVersion version; String path; InstallRecord? record; }`
  - `class SlotMigration { SlotMigration(IOSManager os, String versionsPath, String homeDirectory); Future<MigrationResult> run(); }`
  - `MigrationResult` is `{List<String> renamed, List<String> conflicts}`

- [ ] **Step 1: Write the failing tests** for `SlotMigration.run()` on a temp versions dir.
  ```dart
  test('renames 8.2.28 to 8.2 and repoints the global link', ...);
  //   expect(Directory(p.join(v, '8.2')).existsSync(), isTrue);
  //   expect(os.symlinkTargets[globalLink], p.join(v, '8.2'));
  test('refuses when 8.2.27 and 8.2.28 both exist', ...);
  //   expect(result.conflicts, ['8.2']); both dirs untouched.
  test('second run is a no-op', ...);
  test('a stale local .pvm pointing at versions/8.2.28 is reported by pvm current as stale with hint "pvm use 8.2"', ...); // review focus 1
  ```
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - Rename via `Directory.rename`.
  - Re-point the global `.pvm` link with `IOSManager.createSymLink`.
  - On a conflict, print: `Two patches of 8.2 are installed (8.2.27, 8.2.28). Remove one with: pvm uninstall 8.2.27`. That `uninstall` must still accept a full patch while a conflict exists.
  - Local project links can't all be found. `CurrentCommand` treats a link target whose basename has a patch as stale and prints the hint.
  - `.pvmrc` values holding a full patch resolve to their slot through `PhpVersion.slot`.
- [ ] **Step 4:** Run the full suite. Fix the existing tests that assert `versions/8.3.14` paths so they expect `versions/8.3`.
- [ ] **Step 5:** Commit: `feat: one slot per minor version, with migration`.

### Task 3: Display `8.5 (8.5.22)`

**Files:**
- Create: `lib/src/core/version_label.dart`
- Modify: `lib/src/commands/list_command.dart`, `current_command.dart`, `use_command.dart`, `global_command.dart`, `doctor_command.dart`
- Test: `test/core/version_label_test.dart`, plus updates to the existing command tests.

**Interfaces:**
- Produces: `String versionLabel(PhpVersion slot, String? fullPatch)`. It returns `'8.5 (8.5.22)'`, or `'8.5'` when `fullPatch` is null.

- [ ] **Step 1:** Write the tests: `expect(versionLabel(PhpVersion(8,5), '8.5.22'), '8.5 (8.5.22)'); expect(versionLabel(PhpVersion(8,5), null), '8.5');`. Then add one assertion per command that its output contains `8.5 (8.5.22)`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement it, and use it at every place those commands print an installed version.
- [ ] **Step 4:** Run the full suite. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: show installed versions as minor (patch)`.

### Task 4: `FolderProbe`

**Files:**
- Create: `lib/src/services/folder_probe.dart`
- Modify: `test/services/fake_process_manager.dart`, so `runCaptured` returns a configurable `CapturedProcessResult` keyed by executable.
- Test: `test/services/folder_probe_test.dart`

**Interfaces:**
- Consumes: `IProcessManager.runCaptured`, `PhpLayout`, `PlatformInfo`
- Produces:
  - `class ProbeResult { String version; bool zts; String arch; String apiNo; String? phpConfig; String? prefix; String extensionDir; bool writable; String? vsVersion; }`
  - `class FolderProbe { FolderProbe(IProcessManager pm, PlatformInfo platform); Future<ProbeResult> probe(String folder); }`
  - It throws `ProbeException(String message)`, defined in `lib/src/domain/exceptions/probe_exception.dart` and extending `PvmException`.

- [ ] **Step 1: Write the failing tests.** Fake `php` output is one JSON line, from `php -n -r '<script>'` printing `{"v":PHP_VERSION,"zts":PHP_ZTS,"arch":php_uname("m"),"ext":PHP_EXTENSION_DIR,"build":<"PHP Extension Build" line>}`.
  - Parses `8.4.27`, `zts=false`, `apiNo='20240924'` from the line `API20240924,NTS`.
  - On Unix, finds `bin/php-config8.4` when plain `php-config` is missing. It sets `prefix` from `php-config --prefix`.
  - On Windows, reads `vsVersion: 'VS17'` from the build line. `phpConfig` is null.
  - `writable` is false when `extensionDir` can't be written (temp dir set read-only; skip on Windows).
  - It throws `ProbeException` when `bin/php` is missing, or when `php` exits non-zero.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement. Run the probe script with `-n` so a broken ini can't break it. Check writability by creating and deleting `.pvm-write-test` in `extensionDir`.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: folder probe for version capabilities`. This is the end of PR A.

### Task 5: Host architecture and `arm64`

**Files:**
- Modify:
  - `lib/src/domain/php_release.dart`: add `Architecture.arm64`, and map `'aarch64'`/`'arm64'` to it in `architectureFromString`.
  - `lib/src/core/platform_info.dart`: add `String get hostArch`, from `Abi.current()` in `dart:ffi`, mapped to `'x86_64' | 'aarch64'`.
- Test: `test/domain/php_release_test.dart`, `test/core/platform_info_test.dart`

- [ ] **Step 1:** Write the tests: `expect(PhpRelease.architectureFromString('aarch64'), Architecture.arm64);`, and check that every `PlatformInfo` implementation returns a non-empty `hostArch`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: arm64 architecture and host arch detection`.

### Task 6: `StaticPhpReleaseSource` and tar.gz install

**Files:**
- Create: `lib/src/services/static_php_release_source.dart`
- Modify: `lib/src/services/installation/artifact_installer.dart`, to add `extractTarGz` and choose the extractor by URL suffix. Single-file archives (`php` at the root) are placed at `bin/php` and made executable.
- Test: `test/services/static_php_release_source_test.dart`, `test/services/installation/artifact_installer_test.dart`

**Interfaces:**
- Produces:
  - `class StaticPhpReleaseSource implements IReleaseSource { StaticPhpReleaseSource({required http.Client client, required String os /* 'linux'|'macos' */}); }`
  - `ArtifactInstaller.install(...)` gains a `SlotKind kind` parameter, written into the record.

- [ ] **Step 1: Write the failing tests** against a fixture HTML listing saved from the real page, at `test/fixtures/static_php_bulk_listing.html`. Cut it to about 20 rows.
  - `resolve(8.4)` picks the newest `php-8.4.*-cli-<os>-<arch>.tar.gz` that has a `.sha256` sibling.
  - `resolve(8.4.27)` returns exactly that build.
  - `resolve(8.3.34)` (no such patch) throws `NoMatchingReleaseException`, and its message lists the available `8.3.x` (Q7).
  - The request carries the `User-Agent` header from Global constraints.
  - `sha256` is the first token of the sidecar body.
  - Installer: a tar.gz with a lone `php` yields `<slot>/bin/php` with mode `0755` (skip the mode check on Windows).
  - Installer: a tar entry that is `../evil` or a symlink is rejected.
  - Installer: an HTTP stream that fails halfway leaves the old slot byte-identical, with no `.staging-*` dir left (review focus 4).
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement. Reuse `_validateUrl` with allowed host `dl.static-php.dev`. The tar.gz path uses `GZipDecoder` and `TarDecoder` from `package:archive`, with the same zip-slip guards as `extractZip`.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: static-php release source and tar.gz install`.

### Task 7: `StaticPhpInstaller`; remove apt/brew installers (Q2, roadmap 3.4)

**Files:**
- Create: `lib/src/managers/static_php_installer.dart`
- Delete:
  - `lib/src/managers/linux_installer.dart`
  - `lib/src/managers/macos_installer.dart`
  - `lib/src/managers/package_manager_installer.dart`
  - `lib/src/services/linux_release_fetcher.dart`
  - `lib/src/services/macos_release_fetcher.dart`
  - their tests
- Modify:
  - `lib/src/app.dart` (`_createInstaller`)
  - `lib/src/services/release_fetcher_factory.dart`
  - `lib/src/commands/install_command.dart`: drop `--ts`/`--nts` on Unix; `--arch` defaults to `platform.hostArch`.
- Test: `test/managers/static_php_installer_test.dart`, `test/commands/install_command_test.dart`

**Interfaces:**
- Consumes: `StaticPhpReleaseSource`, `ArtifactInstaller`, `FolderProbe`
- Produces: `class SlotFilledException implements Exception { final String slot; final String installed; }` in `i_installer.dart`. Every installer throws it.

- [ ] **Step 1: Write the failing tests.**
  - `install('8.4')` writes `versions/8.4/bin/php`, and the record has `kind: static`, `phpConfig: null`.
  - With 8.2 at 8.2.28 installed, `install('8.2.29')` throws `SlotFilledException`.
  - `InstallCommand` prints exactly `8.2 is installed (8.2.28). Run: pvm update 8.2` and returns `ExitCode.generalError`.
  - After the files are written, the probe runs inside staging, and its result lands in the record.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement, and make `WindowsInstaller` throw `SlotFilledException` too, for the same message on every OS.
- [ ] **Step 4:** Run the full suite and `rtk fvm dart analyze`. Expected: PASS, with no references left to the deleted files.
- [ ] **Step 5:** Commit: `feat: static-php installer on Linux/macOS; remove apt/brew installers`.

### Task 8: `--from-source` (roadmap 3.2)

**Files:**
- Create:
  - `lib/src/services/build_tools.dart`
  - `lib/src/managers/source_build_installer.dart`
- Modify:
  - `lib/src/commands/install_command.dart`: add the `--from-source` flag. On Windows it is a usage error.
  - `lib/src/app.dart`
- Test: `test/services/build_tools_test.dart`, `test/managers/source_build_installer_test.dart`

**Interfaces:**
- Produces:
  - `class MissingToolsException implements Exception { final List<String> missing; final String installCommand; }`
  - `class BuildTools { BuildTools(IProcessManager pm, PlatformInfo platform, {String osReleasePath = '/etc/os-release'}); Future<void> require(List<String> tools, {List<String> devPackages = const []}); }`
  - `class SourceBuildInstaller implements IInstaller`, writing `kind: source`.

- [ ] **Step 1: Write the failing tests.**
  - The `BuildTools.require` message comes from `/etc/os-release` `ID` / `ID_LIKE`:

    | Distro | Command |
    |---|---|
    | `ubuntu`, `debian` | `sudo apt install build-essential autoconf bison re2c pkg-config <dev pkgs>` |
    | `fedora`, `rhel` | `sudo dnf install gcc make autoconf bison re2c pkgconf <devel pkgs>` |
    | `arch` | `sudo pacman -S base-devel ...` |
    | `alpine` | `sudo apk add build-base autoconf ...` |
    | macOS | `xcode-select --install`, then `brew install autoconf bison re2c pkg-config ...` |
    | unknown | lists the tool names only |

  - Each one ends with `Then run the same pvm command again.`
  - `SourceBuildInstaller` with a fake process manager:
    - It verifies the tarball against the `sha256` for `php-<v>.tar.xz` in `https://www.php.net/releases/index.php?json&version=<v>`.
    - `configure` gets `--prefix=<versions>/8.4`, `--with-config-file-path=<versions>/8.4/etc`, `--with-config-file-scan-dir=<versions>/8.4/etc/conf.d`, and the bundled flag list.
    - `make install` gets `INSTALL_ROOT=<staging>`.
    - On a `make` failure the old `versions/8.4` is untouched.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - The prefix is the *final* slot path. Staging works through `make install INSTALL_ROOT=<staging>`, then moving `<staging><prefix>` into place with `ArtifactInstaller`'s commit.
  - The bundled configure flags are the ones used in the WSL test, recorded in the spec's "Proven so far" section. Copy them into `const sourceConfigureFlags` with a one-line comment that points to the spec.
  - The ubuntu/debian `-dev` list is the 22-package list from the WSL test: `libxml2-dev libsqlite3-dev libssl-dev libcurl4-openssl-dev libonig-dev libzip-dev libicu-dev libpng-dev libjpeg-dev libfreetype6-dev libwebp-dev libsodium-dev libpq-dev libreadline-dev zlib1g-dev libgmp-dev libxslt1-dev`.
  - For the other distros, use the asdf-php README lists cited in `research_notes/PHP sources and extensions per platform/php_sources_per_platform.md`.
  - Print `Building PHP 8.4.27 from source (about 5 minutes)...` before configure starts.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Manual check on WSL Ubuntu, in `~` and not `/mnt/c`: `fvm dart run pvm.dart install 8.4 --from-source`. Expected: `versions/8.4/bin/php-config` exists, and `pvm current` shows `8.4 (8.4.27)`. Afterwards, remove any apt packages you added (see `/var/log/apt/history.log`).
- [ ] **Step 6:** Commit: `feat: pvm install --from-source`. This is the end of PR B.

### Task 9: `pvm link` (roadmap 3.3)

**Files:**
- Create: `lib/src/commands/link_command.dart`
- Modify:
  - `lib/src/commands/uninstall_command.dart`: on a linked slot, delete only the link and its record.
  - `lib/src/domain/version_registry.dart`: read linked records.
  - `lib/src/app.dart`
- Test: `test/commands/link_command_test.dart`, `test/commands/uninstall_command_test.dart`

**Interfaces:**
- Consumes: `FolderProbe`, `IOSManager.createSymLink`
- Produces: a linked slot is the link `versions/<X.Y>` → folder, plus the record `versions/<X.Y>.pvm-link.json`, an `InstallRecord` with `kind: linked`. PVM never writes inside the folder.

- [ ] **Step 1: Write the failing tests.**
  - `pvm link 8.4 /opt/plesk/php/8.4`, with a probe reporting 8.4.15, creates the link and the record, and prints `Linked 8.4 (8.4.15) → /opt/plesk/php/8.4`.
  - A version mismatch (the probe says 8.3.9) prints `That folder has PHP 8.3.9, not 8.4` and exits with `usageError`.
  - A missing `php` exits with `usageError`.
  - A filled slot throws `SlotFilledException`.
  - Uninstall removes the link and the JSON and leaves the folder alone.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: pvm link <version> <folder>`.

### Task 10: Per-slot ini, passed only to PVM's child

**Files:**
- Create: `lib/src/services/slot_ini.dart`
- Modify:
  - `lib/src/services/php_executor.dart`: add the ini arguments/env to the child `ProcessSpec` only.
  - Each installer's post-install step creates `etc/php.ini` and `etc/conf.d/` for every kind except `linked`. On Windows, the ini stays `<slot>/php.ini`.
- Test: `test/services/slot_ini_test.dart`, `test/services/php_executor_test.dart`

**Interfaces:**
- Produces:
  - `class SlotIni { SlotIni(String slotDir, InstallRecord record, PlatformInfo platform); String get confDir; Future<void> enable(String ext, {required bool zend}); Future<void> disable(String ext); Future<void> remove(String ext); ({List<String> args, Map<String, String> env}) childInvocation(); }`
  - One file per extension: `conf.d/50-<ext>.ini`, containing `extension=<ext>` or `zend_extension=<abs path>`. Disabling renames it to `.ini.disabled`.

- [ ] **Step 1: Write the failing tests.**
  - Static slot: `childInvocation()` returns `args: ['-c', '<slot>/etc/php.ini']` and `env: {'PHP_INI_SCAN_DIR': '<slot>/etc/conf.d'}`.
  - Source slot: both are empty, since the paths are compiled in.
  - Linked slot: both are empty, so the system's own ini is used.
  - Windows-zip slot: `args` is empty, since `php.exe` reads its own `<slot>/php.ini`, and `env` is `{'PHP_INI_SCAN_DIR': '<slot>/conf.d'}`.
  - `PhpExecutor` passes the env on the child spec only. The test asserts that `Platform.environment` is unchanged and the parent's env map isn't mutated.
  - Enabling, disabling and removing produce the expected files.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: per-slot ini passed only to PVM-started PHP`. This is the end of PR C.

### Task 11: Extension download, check and rollback

**Files:**
- Create: `lib/src/services/extensions/extension_artifact.dart`
- Test: `test/services/extensions/extension_artifact_test.dart`

**Interfaces:**
- Produces:
  - `Future<bool> exportsZendExtension(File binary)`: true when the bytes contain `zend_extension_entry`.
  - `Future<void> checkLoads(IProcessManager pm, String php, SlotIni ini, String ext)`: runs `php -m` through `ini.childInvocation()` and throws `ExtensionLoadException(ext, stderr)` if `ext` isn't listed.
  - `class ExtensionInstallTxn { Future<void> commit(File built, String extensionDir, SlotIni ini, String ext); }`: copies the file, enables the ini, runs `checkLoads`, and on failure deletes the copied file and the ini, then rethrows.
- Constraint: the name check, `RegExp(r'^[a-z0-9_]+$')`, lives in `ExtensionArtifact.validateName(String)` and is used by Task 13.

- [ ] **Step 1: Write the failing tests.**
  - A byte fixture containing `zend_extension_entry` returns true; plain bytes return false.
  - A load-check failure removes both the copied `.so` and `50-<ext>.ini`.
  - `validateName('../x')` and `validateName('a/b')` throw `UsageException`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: extension install transaction with load check and rollback`.

### Task 12: Build and DLL routes

**Files:**
- Create:
  - `lib/src/services/extensions/pecl_source_builder.dart`
  - `lib/src/services/extensions/pecl_windows_dll.dart`
- Test: `test/services/extensions/pecl_source_builder_test.dart`, `test/services/extensions/pecl_windows_dll_test.dart`

**Interfaces:**
- Consumes: `BuildTools.require`, `ArtifactInstaller.download` (hosts `pecl.php.net`, `downloads.php.net`), `ExtensionInstallTxn`
- Produces:
  - `class PeclSourceBuilder { Future<ExtensionEntry> install(String ext, InstalledSlot slot); }`. It fetches `https://pecl.php.net/rest/r/<ext>/stable.txt`, then `https://pecl.php.net/get/<ext>-<ver>.tgz`, then runs `phpize`, `./configure --with-php-config=<phpConfig>` and `make -j<cpus>` in a temp dir.
  - `class PeclWindowsDll { Future<ExtensionEntry> install(String ext, InstalledSlot slot); }`. URL: `https://downloads.php.net/~windows/pecl/releases/<ext>/<ver>/php_<ext>-<ver>-<X.Y>-<nts|ts>-<vsNN lower>-<x64|x86>.zip`. It puts `php_<ext>.dll` into `<slot>/ext` and any other DLLs next to `php.exe`.
  - `class ExtensionUnavailableException implements Exception`: thrown on a 404. Its message reads like `xdebug 3.5.3 has no Windows build for PHP 8.4 NTS VS17 x64`.

- [ ] **Step 1: Write the failing tests.**
  - The builder calls `BuildTools.require(['cc','make','autoconf','pkg-config','phpize'])`.
  - It refuses with `Slot 8.4 was built for <old prefix>; reinstall it with pvm install 8.4 --from-source --force` when `php-config --prefix` doesn't match the slot. That's the prefix guard.
  - It refuses with `Slot 8.4 is broken (bin/php missing); reinstall it` when the binary is gone (review focus 2).
  - The entry records the tgz's SHA-256 with `verified: false`.
  - For grpc only, it adds `c++` to the required tools and prints `grpc is a long C++ build (can take 30+ minutes).`
  - DLL: the URL is built from the record's `zts`, `vsVersion` and `arch`.
  - DLL: a 404 maps to `ExtensionUnavailableException`.
  - DLL: the entry is `verified: false` with the zip's SHA-256.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement. PIE is not used in this plan (my call, B1); PVM drives phpize/make itself.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: PECL source build and Windows DLL routes`.

### Task 13: `pvm ext install`

**Files:**
- Create: `lib/src/commands/ext_command.dart`, a parent command `ext` with an `install` subcommand.
- Modify:
  - `lib/src/core/exit_codes.dart`: add `toolMissing = 7`, `extensionUnavailable = 8`, `slotInUse = 9`, `buildFailed = 10`.
  - `lib/src/app.dart`
- Test: `test/commands/ext_command_test.dart`

**Interfaces:**
- Consumes: `ActiveVersionResolver`, `VersionRegistry.installedSlots`, `PeclSourceBuilder`, `PeclWindowsDll`, `ExtensionArtifact.validateName`

- [ ] **Step 1: Write the failing tests**, one per route row in the spec.

  | Case | Expected |
  |---|---|
  | No `--version`, with local 8.3 and global 8.4 | Targets 8.3 |
  | Already in `php -m` | `xdebug is already enabled for 8.4 (8.4.27)`, exit 0 |
  | `windowsZip` | Calls `PeclWindowsDll` |
  | `source` | Calls `PeclSourceBuilder` |
  | `linked` + writable + `phpConfig` | Calls `PeclSourceBuilder` |
  | `linked` + not writable, with `phpConfig` `/usr/bin/php-config8.4` | Prints `sudo apt install php8.4-xdebug`, exit `toolMissing` (7) |
  | `linked` + not writable, Plesk-style `/opt/plesk/php/8.4` | Prints `/opt/plesk/php/8.4/bin/pecl install xdebug` |
  | `static` | Prints exactly `xdebug isn't in this build. Run: pvm install 8.4 --from-source, or pvm link 8.4 <folder>`, exit `generalError` |
  | `--version=8.1` not installed | Exit `versionNotFound` (3), message lists the slots (review focus 3) |
  | `ext install ../x` | Exit `usageError` (2) (review focus 5) |
  | `MissingToolsException` | Prints its `installCommand`, exit 7 |
  | `ExtensionUnavailableException` | Exit 8 |

  On success, the record gains the `ExtensionEntry`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement it. The system-command line for a non-writable linked slot comes from the prefix:

  | Prefix | Command |
  |---|---|
  | `/usr` (ondrej, sury) | `sudo apt install phpX.Y-<ext>` |
  | `/opt/remi/phpXY/root/usr` | `sudo dnf install phpXY-php-pecl-<ext>` |
  | `/opt/cpanel/ea-phpXY/root/usr` | `/opt/cpanel/ea-phpXY/root/usr/bin/pecl install <ext>` |
  | anything else | `<prefix>/bin/pecl install <ext>` |

- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Manual check on WSL: on a `--from-source` 8.4 slot, run `pvm ext install xdebug`, then `pvm php -m | grep xdebug`. Expected: `xdebug` is listed.
- [ ] **Step 6:** Commit: `feat: pvm ext install`.

### Task 14: `pvm update`

**Files:**
- Create: `lib/src/commands/update_command.dart`
- Modify: `lib/src/app.dart`; `ArtifactInstaller._commit`, so a rename failure on Windows maps to `SlotInUseException`.
- Test: `test/commands/update_command_test.dart`

**Interfaces:**
- Produces: `class SlotInUseException implements Exception { final String slot; }`, with the message `PHP 8.2 is in use (a running php.exe or web server holds its files). Stop it, then run: pvm update 8.2`.

- [ ] **Step 1: Write the failing tests.**
  - On `static` / `windowsZip` it reinstalls the newest patch through staging, and the record's `extensions` carry over.
  - Every Windows DLL is copied into staging and must pass `checkLoads` before the swap. If one fails, the swap is aborted and the message names the extension.
  - On `source` it rebuilds, then re-runs `PeclSourceBuilder` for each recorded extension in staging. Extensions that fail are dropped with the line `xdebug could not be rebuilt; run: pvm ext install xdebug`.
  - On `linked` it prints `8.4 is linked to <folder>; update it there.` and exits 1.
  - Already newest: prints `8.4 (8.4.27) is up to date`, exit 0.
  - A rename failure maps to `SlotInUseException`, exit `slotInUse` (9).
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: pvm update <minor>`.

### Task 15: Switching hint, docs

**Files:**
- Create: `lib/src/services/extension_hint.dart`, `docs/adr/0001-php-sources-and-trust.md`
- Modify:
  - `use_command.dart`, `global_command.dart`, `current_command.dart`: print the hint.
  - `GLOSSARY.md`: add that `pvm ext install` counts as the explicit request for an unverified install.
  - `.agents/plans/cross-platform-roadmap.md`: mark 3.1–3.5 done, and replace the 3.1 "pin hashes" note with Q1.
  - `readme.md`, `AGENTS.md`: the commands and Linux/macOS support. AGENTS.md currently says Windows-only.
- Test: `test/services/extension_hint_test.dart`

**Interfaces:**
- Produces: `List<String> extensionHints(InstalledSlot target, List<InstalledSlot> others)`, returning lines like `xdebug is installed for 8.2 but not 8.3. Run: pvm ext install xdebug`.

- [ ] **Step 1: Write the failing tests.**
  - With 8.2 holding `[xdebug]` and 8.3 holding `[]`, the result is that exact line.
  - When the target already has the extension, there's no line.
  - `pvm use 8.3` prints the hint and still exits 0.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement the hint. Write the ADR: context, the decisions Q1–Q7 and E1–E4, and the consequences, each in a few lines taken from the spec.
- [ ] **Step 4:** Run the full suite and `rtk fvm dart analyze`. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: extension hint on switch; ADR 0001 and docs`. This is the end of PR D.
