# Extension installer tools: mechanics, UX, failure handling, verification, and lessons for `pvm ext install`

*Observed 2026-11-10. Sources were read that day: GitHub raw files and the API via `gh`, a shallow clone of `php/pie` at branch `1.6.x`, and web pages. **Inference** marks reasoning. **Unverified** marks claims that were not confirmed in a primary source. This complements `reports/PHP source and extension strategy for Linux and macOS.md` and does not repeat its static-php findings.*

## 1. PIE (php/pie): targeting, downloads, binaries, ini, show/uninstall, verification, PECL deprecation

### Takeaway
PIE is now the officially recommended installer. It picks its target from an explicit `php-config` path (Unix) or `php.exe` path (Windows), and it reads the ABI (API number, TS/NTS, compiler) from `php -i`. On Windows it downloads DLLs from GitHub releases using a strict naming scheme. It can enable the extension through a ranked list of ini strategies, with rollback and a runtime load check. Its one integrity mechanism is a **locally recorded SHA-256 of the installed binary**. Upstream extension downloads are **not** verified against a publisher checksum or attestation. Only PIE itself is attested.

### Cited Findings
- **Releases.** The default branch is `1.6.x`. Latest releases: 1.6.0-rc.2 (2026-11-09), 1.6.0-rc.1 (2026-11-04), and stable 1.5.5 (2026-10-30) — [GitHub API releases](https://github.com/php/pie/releases)
- **Targeting.** PIE installs into the PHP that runs it by default. The `--with-php-config=/usr/bin/php-config7.2` option targets another PHP on non-Windows systems. Windows uses `--with-php-path=C:\php-8.3.6\php.exe`, and `--with-phpize-path` overrides phpize — [usage.md](https://github.com/php/pie/blob/1.6.x/docs/usage.md)
- **PHP requirements.** PIE itself needs PHP 8.1+, but it can install extensions for older PHP versions. It also needs the `zip` extension or `git` — [usage.md](https://github.com/php/pie/blob/1.6.x/docs/usage.md)
- **ABI detection (source).** `TargetPlatform::fromPhpBinaryPath` regex-matches the `PHP Extension Build` line of `phpinfo()` (e.g. `API2024…,NTS,VS17`). From it PIE derives thread safety and the Windows compiler (VC6 to VS18) — [src/Platform/TargetPlatform.php](https://github.com/php/pie/blob/1.6.x/src/Platform/TargetPlatform.php)
- **Download sources.** Packages are Composer packages on Packagist. The `download-url-method` field can be `composer-default` (a GitHub zipball), `pre-packaged-source` (`php_{ext}-{ver}-src.tgz`) or `pre-packaged-binary`. The docs recommend combining `["pre-packaged-binary", "composer-default"]` so PIE falls back to a source build — [extension-maintainers.md](https://github.com/php/pie/blob/1.6.x/docs/extension-maintainers.md)
- **Unix prebuilt binary naming.** `php_{ExtensionName}-{Version}_php{PhpVersion}-{Arch}-{OS}-{Libc}-{Debug}-{TSMode}.{zip|tgz}`, where OS is one of `linux`, `darwin` and others, and Libc is `glibc`, `musl` or `bsdlibc`. The docs say prebuilt binaries with dynamically linked libs are "**not recommended**". A `php/pie-ext-binary-builder` action generates these binaries — [extension-maintainers.md](https://github.com/php/pie/blob/1.6.x/docs/extension-maintainers.md)
- **Windows.** Maintainers "must provide pre-built binaries", because PIE does "not currently support building DLLs on the fly". Only GitHub releases are supported. The asset name is `php_{ext}-{tag}-{maj.min}-{ts|nts}-{compiler}-{arch}.zip`, e.g. `php_xdebug-3.3.2-8.3-ts-vs16-x86_64.zip`. The architecture is normalised to `x86_64`, `arm64` or `x86`. The DLL is renamed to `ext\php_{ext}.dll`, the `.pdb` goes alongside it, other `*.dll` files go next to `php.exe`, and any other files go to `extras\{ext}\` — [extension-maintainers.md](https://github.com/php/pie/blob/1.6.x/docs/extension-maintainers.md)
- **Windows name variants (source).** PIE accepts both `…-{ts}-{compiler}-…` and `…-{compiler}-{ts}-…` orders, lower-cased — [src/Platform/WindowsExtensionAssetName.php](https://github.com/php/pie/blob/1.6.x/src/Platform/WindowsExtensionAssetName.php)
- **Build tool and library checks.** Since 1.4.0 PIE detects missing build tools (gcc, make, autoconf, pkg-config, libtoolize, unzip, phpize) and system libraries, and offers to install them. In non-interactive mode it will **not** install them unless given `--auto-install-build-tools` or `--auto-install-system-dependencies`. `pie check-build-tools` (1.5.0+) runs the check on its own — [usage.md](https://github.com/php/pie/blob/1.6.x/docs/usage.md). Auto-install of system libraries covers apt, apk and dnf for only some libraries (for example lib-sodium and lib-zip; lib-png and lib-avif are checked only) — [extension-maintainers.md](https://github.com/php/pie/blob/1.6.x/docs/extension-maintainers.md)
- **Ini enabling, documented.** PIE writes `extension=` or `zend_extension=` through these approaches in order: `docker-php-ext-enable`, the additional-ini (scan) directory, then the main php.ini. `--skip-enable-extension` turns this off, and PIE warns if none of the approaches works — [usage.md](https://github.com/php/pie/blob/1.6.x/docs/usage.md)
- **Ini enabling, source.** The actual order is PreCheckExtensionAlreadyLoaded, OndrejPhpenmod, DockerPhpExtEnable, StandardAdditionalPhpIniDirectory, StandardSinglePhpIni — [src/Container.php](https://github.com/php/pie/blob/1.6.x/src/Container.php). `AddExtensionToTheIniFile` keeps the original ini content, appends the line, then calls `assertExtensionIsLoadedInRuntime`. On any exception it **restores the original ini** — [src/Installing/Ini/AddExtensionToTheIniFile.php](https://github.com/php/pie/blob/1.6.x/src/Installing/Ini/AddExtensionToTheIniFile.php)
- **Commands present in 1.6.x source:** Build, CheckBuildTools, Download, Info, Install, InstallExtensionsForProject, Repository{Add,List,Remove}, Search, SelfUpdate, SelfVerify, Show, **Uninstall** and Upgrade. There are **no enable or disable commands** — [src/Command/](https://github.com/php/pie/tree/1.6.x/src/Command). (The usage doc's PECL comparison table still leaves `pecl uninstall` blank, which is stale — [usage.md](https://github.com/php/pie/blob/1.6.x/docs/usage.md).)
- **Integrity mechanism (source).** After a build or a Windows prebuilt install, PIE computes the SHA-256 of the `.so` or `.dll` (`BinaryFile::fromFileWithSha256Checksum`) and stores it as `pie-installed-binary-checksum` in Composer `installed.json` metadata — [src/Building/UnixBuild.php](https://github.com/php/pie/blob/1.6.x/src/Building/UnixBuild.php), [src/ComposerIntegration/InstalledJsonMetadata.php](https://github.com/php/pie/blob/1.6.x/src/ComposerIntegration/InstalledJsonMetadata.php)
- **`pie show`** compares the on-disk binary with that metadata and reports statuses such as checksum mismatch, "was built but not installed yet" and "installed but not enabled in INI file" — [src/DependencyResolver/Package.php](https://github.com/php/pie/blob/1.6.x/src/DependencyResolver/Package.php), [src/Command/ShowCommand.php](https://github.com/php/pie/blob/1.6.x/src/Command/ShowCommand.php)
- **`pie uninstall`** refuses if the metadata is missing. It checks that the stored path matches the conventional path (`ext/php_{ext}.dll` or `{ext}.so`), **verifies the stored SHA-256 before unlinking**, and uses sudo if the file is not writable — [src/Installing/UninstallUsingUnlink.php](https://github.com/php/pie/blob/1.6.x/src/Installing/UninstallUsingUnlink.php)
- **No upstream checksum for prebuilt assets.** When PIE switches a package to a prebuilt release asset, it calls `setDistSha1Checksum(null)`, which drops Composer's dist checksum — [src/ComposerIntegration/Listeners/OverrideDownloadUrlInstallListener.php](https://github.com/php/pie/blob/1.6.x/src/ComposerIntegration/Listeners/OverrideDownloadUrlInstallListener.php). No attestation check for extension assets was found in the source. Attestation code exists only under `SelfManage/Verify`, for PIE's own PHAR (`gh attestation verify --owner php pie.phar`, with an OpenSSL fallback) — [src/SelfManage/Verify/](https://github.com/php/pie/tree/1.6.x/src/SelfManage/Verify), [usage.md](https://github.com/php/pie/blob/1.6.x/docs/usage.md)
- **Other features.** Composer-style version constraints (`pie install "xdebug/xdebug:^3.4.3 || 3.4.1"`), per-PHP `pie.json` and `pie.lock` (path shown by `pie show -v`, e.g. `~/.config/pie/php8.2_<hash>/pie.json`), `pie install --from-lock`, and `pie upgrade` within the original constraint. Since 1.6.0, an auto-fetched map from extension name to package resolves `ext-*` requirements (opt out with `PIE_DISABLE_PACKAGE_MAP_FETCH=1`) — [usage.md](https://github.com/php/pie/blob/1.6.x/docs/usage.md)
- **Configure options.** Configure options passed to a `pre-packaged-binary` package make PIE fall back to compiling. `--with-libdir` defaults to the target PHP's configure value — [usage.md](https://github.com/php/pie/blob/1.6.x/docs/usage.md)
- **PECL deprecation.** The RFC "Recommend PIE and deprecate PECL" was accepted 36–0–5, with voting ending 2025-09-20. It is "messaging only". The PECL site and tool "will still function for the time being", and no removal timeline is set (a follow-up RFC is needed) — [wiki.php.net RFC](https://wiki.php.net/rfc/adopt_pie_deprecate_pecl). PECL package pages now say "PECL is deprecated" and call PIE "the replacement for PECL" — [pecl.php.net/package/redis](https://pecl.php.net/package/redis)
- **PIE-ready count.** Packagist's extensions listing has 25 pages: 24 full pages of 15 plus 10 entries on the last page, which is **about 370 packages** (computed from pagination, not a stated total) — [packagist.org/extensions](https://packagist.org/extensions), [page 25](https://packagist.org/extensions?page=25)
- **PECL migration table.** PIE's own table lists about 98 PECL extensions as Supported, 6 as Work in progress, 192 as Not started/Unknown and 131 as Abandoned (counted from table and list rows) — [supported-extensions.md](https://github.com/php/pie/blob/1.6.x/docs/supported-extensions.md). Supported includes apcu, imagick, memcached, mongodb, pcov, phpredis, xdebug, sqlsrv/pdo_sqlsrv, swoole, rdkafka, opentelemetry and oci8. grpc is only `bsn4/grpc`, a Rust replacement — same source.

### Inferences
- `--with-php-config` and `--with-php-path` map one-to-one onto "one PVM-managed version". PVM can shell out to PIE with the version's own paths instead of re-implementing resolution and naming.
- PIE's SHA-256 is tamper *detection after install*, not *authenticity of the download*. PVM should present PIE-sourced binaries as "unverified source, integrity tracked locally" unless it adds its own verification, for example GitHub artifact attestations where the maintainer publishes them (unverified whether any extension does).
- PIE's ini logic targets the system php.ini or scan dir of the target PHP. If PVM owns a per-version ini (`PHPRC` / `PHP_INI_SCAN_DIR`), it should either point PIE at it (PIE picks the scan dir if one is configured) or pass `--skip-enable-extension` and write the ini itself.

### Gaps
- No PHP Foundation blog post with an official "PIE-ready extensions" count was fetched. The about 370 figure is derived from pagination.
- It was not verified whether any PIE extension publishes GitHub artifact attestations for its release assets.
- Linux/macOS `pre-packaged-binary` adoption (how many packages ship `.so` assets) was not measured.

## 2. pecl/PEAR and the Windows PECL DLL service

### Takeaway
pecl.php.net publishes tarballs with **no checksums or signatures** on package pages. The Windows PECL DLL service broke around 2022, came back on 2024-06-07, and is **still producing DLLs in 2026**, for example xdebug 3.5.3 dated 2026-06-08. It too publishes no checksum files. `php/php-windows-builder` is the GitHub Actions route PIE recommends for maintainers. It feeds GitHub releases, not downloads.php.net.

### Cited Findings
- The redis PECL page lists tarballs such as "redis-6.3.0.tgz (389.9kB)" with no md5, sha or signature, and has per-release "DLL" links — [pecl.php.net/package/redis](https://pecl.php.net/package/redis)
- **Outage.** PECL Windows builds were broken from 2022-04-08, and the last good MongoDB DLL build was on 2022-03-23 — [MongoDB PHPC-2143](https://jira.mongodb.org/browse/PHPC-2143). The internals list reported that the Windows PECL build machine died — [externals.io 117494](https://externals.io/message/117494)
- **Restoration.** windows.php.net carried the notice "Windows DLLs for most PECL extensions are back!" dated 07 Jun 2024 (per search snippet). windows.php.net now 302-redirects to `php.net/downloads.php?os=windows`, so the notice was not re-read — [windows.php.net](https://windows.php.net/)
- **Still active in 2026.** `downloads.php.net/~windows/pecl/releases/xdebug/` shows 3.5.3 (2026-06-08), 3.5.1 (2026-03-18) and 3.5.0 (2025-12-08) — [listing](https://downloads.php.net/~windows/pecl/releases/xdebug/)
- **Layout.** xdebug 3.5.3 has 24 zips covering PHP 8.0–8.5 × ts/nts × x64/x86, with vs16 for 8.0–8.3 and vs17 for 8.4–8.5, e.g. `php_xdebug-3.5.3-8.4-nts-vs17-x64.zip`. There is a `logs/` subdirectory, no `.sha256` or `.asc`, and no arm64 build — [3.5.3 listing](https://downloads.php.net/~windows/pecl/releases/xdebug/3.5.3/)
- **Naming difference.** PECL uses `x64`, PIE normalises to `x86_64`. PhpManager (used by setup-php) builds its regex as `-(nts|ts)-(VC|vc|vs){N}-{arch}.zip`. It searches `downloads.php.net/~windows/pecl/releases/{ext}/{ver}/`, falls back to `…/pecl/snaps/…`, and treats a 404 as "not available" — [Get-PeclArchiveUrl.ps1](https://github.com/mlocati/powershell-phpmanager/blob/master/PhpManager/private/Get-PeclArchiveUrl.ps1)
- **php-windows-builder.** It provides `extension-matrix`, `extension` and `release` actions. The matrix auto-derives PHP versions from `composer.json` and defaults to x64/x86 and nts/ts. VS mapping: 7.2–7.4 vc15, 8.0–8.3 vs16, 8.4–8.5 vs17, 8.6/master vs18 (on a `windows-2025-vs2026` runner). Tests run by default — [php-windows-builder README](https://github.com/php/php-windows-builder)
- PIE's PECL comparison maps `pecl package` (Windows) to "use `php/php-windows-builder` action" — [usage.md](https://github.com/php/pie/blob/1.6.x/docs/usage.md)

### Inferences
- On Windows PVM has two DLL sources: the PECL DLL directory (broad coverage, no checksums, x64/x86 only) and PIE's GitHub releases (same build tooling, no checksums either, but GitHub-hosted and possibly attested). Neither gives a publisher checksum today, so the prior report's question 5 ("unverified install" flag) applies to both.
- The VS version must come from the target `php.exe` (`php -i`), not a lookup table, because 8.6 moves to vs18.

### Gaps
- No primary source says whether the downloads.php.net PECL DLL service is officially maintained long-term or slated for retirement alongside PECL.
- The `logs/` directory was not inspected for build provenance.

## 3. docker-php-extension-installer (mlocati)

### Takeaway
This is the most battle-tested "extension → system packages" mapping. It is a 6,000-line shell `case` table per extension per distro, split into persistent and volatile (build-only) packages. It installs into official Docker images only. It supports pinning with `-ver`, `-^ver`, `@stable`/`-beta` and git refs. Before enabling, it **checks that the module loads** by diffing PHP's startup stderr.

### Cited Findings
- **Scope.** It works only in official Docker php images: Debian since jessie (PHP 5.5+) and Alpine since 3.9 (PHP 7.1+). It installs the needed APT/APK packages and removes the "no-more needed packages" at the end. The latest release is 2.13.2 (2026-11-02) — [README](https://github.com/mlocati/docker-php-extension-installer), [releases](https://github.com/mlocati/docker-php-extension-installer/releases)
- **Supported list.** `data/supported-extensions` has 164 extensions with per-PHP-version lists. 69 entries end at 8.5 and 68 mention 8.6 — [data/supported-extensions](https://github.com/mlocati/docker-php-extension-installer/blob/master/data/supported-extensions)
- **Mapping mechanics.** `buildRequiredPackageLists()` is a per-`ext@distro` case. Example `imagick@debian`: Debian 13+ gets `libmagickwand-7.q16-*`, older releases get `-6.q16-*`, both plus ghostscript. It accumulates `_persistent` (runtime) and `_volatile` (build-only) package lists. It also probes PHP's OpenSSL version (`OPENSSL_VERSION_NUMBER`) so that it picks matching libssl dev packages — [install-php-extensions](https://github.com/mlocati/docker-php-extension-installer/blob/master/install-php-extensions)
- **Pinned libraries.** Bundled library versions are pinned in-script (e.g. `IPE_LIBVERSION_ZSTD=1.5.7`). `data/dependencies.json` tracks the upstream source of each — [install-php-extensions](https://github.com/mlocati/docker-php-extension-installer/blob/master/install-php-extensions), [dependencies.json](https://github.com/mlocati/docker-php-extension-installer/blob/master/data/dependencies.json)
- **Version syntax.** `xdebug-2.9.7`, `xdebug-^2`, `xdebug-^3@stable` (suffixes `@snapshot`, `@devel`, `@alpha`, `@beta`, `@stable`), `mongodb-stable`, `xdebug-beta`, and sources like `owner/repo@sha|tag|branch`, a tarball URL or a local dir. Bundled extensions such as `zip` use the bundled copy unless given a stability suffix (`zip-stable`, which means PECL) — [README](https://github.com/mlocati/docker-php-extension-installer)
- **Special requirements.** Per-distro exclusions and `zts`-only extensions such as parallel and pthreads, e.g. `parallel zts` and `v8js !buster !bullseye …` — [data/special-requirements](https://github.com/mlocati/docker-php-extension-installer/blob/master/data/special-requirements)
- **Load check.** `checkModuleWorking` captures `php -r 'return;'` stderr, writes a temporary `conf.d/docker-php-ext-<ext>--temp.ini`, captures stderr again and fails if the output changed — [install-php-extensions](https://github.com/mlocati/docker-php-extension-installer/blob/master/install-php-extensions)
- **Zend vs plain extension.** It decides between `zend_extension` and `extension` by running `readelf --syms` and looking for the `zend_extension_entry` symbol — [install-php-extensions](https://github.com/mlocati/docker-php-extension-installer/blob/master/install-php-extensions)
- **Other behaviour.** It strips symbols by default (`IPE_NOSTRIP=1` keeps them). `IPE_DONT_ENABLE=1` installs without enabling and generates `docker-php-ext-enable-<ext>` for later. `IPE_SKIP_CHECK=1` skips the load check. `IPE_SAVE_PERMDEPS_TO` / `IPE_SAVE_VOLDEPS_TO` export the dependency lists — [README](https://github.com/mlocati/docker-php-extension-installer)

### Inferences
- The persistent/volatile split is a model for PVM. If PVM ever installs system packages, it should record which ones it added so they can be removed later.
- Use the extensions with the most 8.x coverage in `supported-extensions` as the test matrix for "what people install".
- The stderr-diff load check is cheap and catches ABI mismatch, missing shared libs and undefined symbols before PVM commits the ini.

### Gaps
- No download counts or popularity ranking per extension was found. The supported list is a proxy, not usage data.

## 4. shivammathur/setup-php extension handling

### Takeaway
setup-php is per-OS. Ubuntu uses ondrej `phpX.Y-ext` apt packages, falling back to PECL. macOS uses the shivammathur/extensions Homebrew tap, falling back to PECL. Windows uses PhpManager against PECL DLLs, with backups and a "did it actually load" check. Failures are warnings by default; the `fail-fast` flag makes them errors.

### Cited Findings
- **OS support.** Ubuntu covers "package, … PECL or a git repository". Windows covers PECL extensions "which have the `DLL` binary". macOS covers PECL or git — [README](https://github.com/shivammathur/setup-php). The latest release is 2.40.0 (2026-10-08) — [releases](https://github.com/shivammathur/setup-php/releases)
- **Syntax.** `swoole-1.9.3` (version), `xdebug-beta` (minimum stability), `:mbstring` (disable, plus its dependents), `none` (disable all shared extensions, hoisted first), `intl-77.1` (ICU version) — [README](https://github.com/shivammathur/setup-php)
- **Failure policy.** Extensions that cannot be added "gracefully leave an error message in the logs". `fail-fast: true` fails the job instead — [README](https://github.com/shivammathur/setup-php)
- **Caching.** Extensions are cached through `shivammathur/cache-extensions` plus `actions/cache` — [README](https://github.com/shivammathur/setup-php#cache-extensions). Tools, not extensions, can be pinned to `@sha256:<hash>` — [README](https://github.com/shivammathur/setup-php)
- **Linux mechanics.** `add_extension_helper` adds the ondrej PPA and installs `php$version-$ext` (plus `-dbgsym` for debug builds) if `apt-cache policy` shows a Candidate, otherwise it runs `pecl_install` — [src/scripts/linux.sh](https://github.com/shivammathur/setup-php/blob/main/src/scripts/linux.sh)
- **macOS mechanics.** `add_brew_extension` first tries to enable an existing build. Otherwise it taps `shivammathur/extensions` and runs `brew install --skip-link <tap>/<formula>@<version>`. It retries after `update_dependencies`, then falls back to `pecl_install ext-version` and then plain `pecl_install ext` — [src/scripts/darwin.sh](https://github.com/shivammathur/setup-php/blob/main/src/scripts/darwin.sh)
- **Windows mechanics.** It uses PhpManager's `Install-PhpExtension` with Minimum/MaximumStability, and treats 8.1–8.4 as `snapshot` minimum "till DLLs … are released as stable". Before replacing a DLL it moves the existing one to a versioned backup. It restores the backup on failure. It probes cached DLLs and deletes them if they "target another PHP build". Dependency DLLs are **symlinked into the PHP dir** rather than added to PATH, because "other actions change the PATH". Nightly PHP uses `shivammathur/php-extensions-windows` release DLLs named `php{ver}_{ts}_{arch}_{ext}.dll` — [src/scripts/extensions/add_extensions.ps1](https://github.com/shivammathur/setup-php/blob/main/src/scripts/extensions/add_extensions.ps1)
- **Dependencies.** An extension-dependency map (`extension_map.php`) enables required shared extensions first and disables dependents on `:ext` — [add_extensions.ps1](https://github.com/shivammathur/setup-php/blob/main/src/scripts/extensions/add_extensions.ps1)

### Inferences
- In setup-php's source order, prebuilt packages come first and a compile is the fallback. That matches the prior report's recommendation (PIE or prebuilt first, compile second).
- Copy the backup-then-restore and "enable, then confirm loaded, else roll back" patterns. Windows cannot overwrite a loaded DLL anyway (see §7).

### Gaps
- No specific user-facing error message text for failed extensions was collected beyond the log-and-continue policy.

## 5. phpbrew `ext`, Herd, and Laragon

### Takeaway
phpbrew is the closest precedent for a per-version CLI. It uses one ini file per extension and disables an extension by renaming it to `.ini.disabled`, per SAPI. Herd (Windows) and Laragon have no installer at all: users fetch NTS DLLs by hand and edit php.ini. Laragon adds only a menu toggle for extensions that already exist.

### Cited Findings
- **phpbrew commands.** `ext clean`, `config`, `disable`, `enable`, `install`, `known` and `show` — [ExtensionCommand dir](https://github.com/phpbrew/phpbrew/tree/master/src/PhpBrew/Command/ExtensionCommand). `disable` takes `-s|--sapi` — [DisableCommand.php](https://github.com/phpbrew/phpbrew/blob/master/src/PhpBrew/Command/ExtensionCommand/DisableCommand.php)
- **phpbrew mechanics.** `ExtensionManager` creates a per-extension config file. Disable renames it to `<file>.disabled` and enable renames it back. It also has `disableAntagonists` and `hasConflicts` for mutually exclusive extensions — [ExtensionManager.php](https://github.com/phpbrew/phpbrew/blob/master/src/PhpBrew/Extension/ExtensionManager.php)
- **Herd Windows.** Users download "non-thread-safe Windows versions" from PECL and edit `%USERPROFILE%\.config\herd\bin\<version>\php.ini`, once per version. There is no extension UI — [Herd Windows docs](https://herd.laravel.com/docs/windows/technology/php-extensions)
- **PIE vs Herd (macOS).** The PIE issue "Support Laravel Herd, where extension_dir does not exist and absolute paths are used in INI" is still open. Error: "Could not determine extension path for …/Herd/bin/php84" — [php/pie#504](https://github.com/php/pie/issues/504)
- **Laragon.** The PHP > Extensions menu toggles extensions by commenting or uncommenting php.ini lines. New DLLs are copied by hand into `ext` and added as `extension=php_redis.dll` — [dev.to guide (community)](https://dev.to/dendihandian/installing-php-redis-extension-on-laragon-2mp3). **Unverified** against official Laragon docs: laragon.org/docs/php-extensions returned 404.

### Inferences
- PVM can beat the GUI tools simply by automating the DLL fetch, ABI match and ini write.
- Two features worth copying from phpbrew: rename-to-`.disabled` (or `;extension=`) disable that keeps the binary, and a conflict list (e.g. xdebug and pcov both hooking coverage; **inference**, not taken from phpbrew's list).

### Gaps
- No official Laragon documentation was found for its extension menu.

## 6. Homebrew shivammathur/extensions tap

### Takeaway
The tap ships prebuilt bottles named `<ext>@<X.Y>` for PHP 5.6–8.7, but now **only for Linux x86_64 and macOS arm64 ("macOS Intel is not supported")**. It requires `brew trust` of the tap.

### Cited Findings
- **Support matrix.** PHP 5.6 to 8.7. OS: Linux x86_64, and macOS arm64 on Golden Gate, Tahoe and Sequoia. The README says "macOS Intel is not supported." The Formula dir has 825 entries — [README](https://github.com/shivammathur/homebrew-extensions), [Formula](https://github.com/shivammathur/homebrew-extensions/tree/main/Formula)
- **Usage.** `brew tap shivammathur/extensions`, `brew trust shivammathur/extensions`, `brew install shivammathur/extensions/xdebug@8.4`, `brew upgrade …`. It works with PHP from `shivammathur/php` or `homebrew/core` — [README](https://github.com/shivammathur/homebrew-extensions)
- **Coverage.** The list includes grpc, imagick, memcached, mongodb, pcov, redis-class extensions (igbinary, msgpack), pdo_sqlsrv, opentelemetry and more, mostly "PHP 5.6 to PHP 8.7" — [README](https://github.com/shivammathur/homebrew-extensions)

### Inferences
- The tap is only usable against a *Homebrew* PHP, because bottles link Homebrew's libs and php@X.Y. It fits a `pvm link`-ed brew PHP, not a static-php or PVM-built PHP.
- The prior report listed "x86_64/arm64 Linux" for bottles. The README now shows Linux x86_64 only and no Intel macOS, which narrows that alternative.

### Gaps
- It was not checked whether the bottle sha256s are pinned per formula for all 825 formulae (the prior report checked grpc@8.3 only).

## 7. Common failure modes (from issue trackers)

### Takeaway
The recurring failures are: wrong or undetectable target PHP or extension dir; a relative `extension_dir` on Windows; a locked DLL on reinstall; GitHub rate limits silently turning a binary install into a source build; missing build tools or sudo; and an ini that was written but not loaded. ABI mismatch (API, TS/NTS, VS, debug) is avoided only by reading `php -i` of the target.

### Cited Findings
- **Windows relative `extension_dir`.** With `extension_dir = "ext"` (relative to `php.exe`), PIE 1.3.1 put the DLL in `C:\ext` and showed no error — [php/pie#451](https://github.com/php/pie/issues/451)
- **Windows locked DLL.** Reinstall or uninstall of a loaded DLL fails with "Resource temporarily unavailable", because Windows locks loaded DLLs — [php/pie#190](https://github.com/php/pie/issues/190)
- **Rate limits.** A GitHub API 403 rate limit on the release lookup went "directly" to source compilation. This led to a flag to prevent source fallback — [php/pie#701](https://github.com/php/pie/issues/701), with `--download-method` requested for reproducible binary-only installs — [php/pie#589](https://github.com/php/pie/issues/589)
- **Unusual layout (Herd).** Herd has no extension_dir, so PIE cannot determine the extension path — [php/pie#504](https://github.com/php/pie/issues/504)
- **Other PIE issues by title.** "Installation when php has a prefix or postfix" (#284), "The php binary at /usr/local/bin/php does not appear to be a PHP binary" (#475), "Unable to ask sudo password" (#517), "Pie attempts to install missing build tools without sudo" (#597), "RPM distro: php-devel is not the right package" (#640), "On FreeBSD, gmake instead of make" (#650), "Huge make output … cause PIE to hang" (#327), "Could not find release by tag name" for pecl/yaml on Windows (#598), "Varying non-zero exit codes" (#416, open) — [php/pie issues](https://github.com/php/pie/issues?q=is%3Aissue)
- **PIE's own checksum code.** On Ubuntu PHP 8.1.2, checksum verification failed because that build's `hash_file()` lacks the 4th parameter — [php/pie#757](https://github.com/php/pie/issues/757)
- **ABI.** PIE reads "PHP Extension Build" (API, TS/NTS, compiler) from `php -i` — [TargetPlatform.php](https://github.com/php/pie/blob/1.6.x/src/Platform/TargetPlatform.php). Laragon and Herd users must match TS/NTS and the VS build by hand — [Herd Windows docs](https://herd.laravel.com/docs/windows/technology/php-extensions)
- **ZTS-only extensions** (parallel, pthreads) fail on NTS PHP — [special-requirements](https://github.com/mlocati/docker-php-extension-installer/blob/master/data/special-requirements)

### Inferences
- PVM controls the layout, so it can avoid #451 and #504 by always using an absolute `extension_dir` in its per-version ini.
- PVM can avoid #190 by never running the target PHP while it replaces a DLL. PVM itself is Dart, not PHP, so it does not hold the DLL, but a running `php-cgi` or server would. Detect that and tell the user to stop it.

### Gaps
- No quantitative ranking of failure frequency was available. The list is by issue title and comment count.

## 8. Enable/disable without uninstalling, and listing per version

### Takeaway
Every mature tool separates "binary present" from "enabled in ini". The common patterns are a per-extension ini file in a scan dir (toggled by rename or delete) and comment-toggling a single php.ini. Listing always comes from running the target PHP (`php -m` / `get_loaded_extensions`) plus a scan of `extension_dir`.

### Cited Findings
- **phpbrew** renames to `.disabled`, per SAPI — [ExtensionManager.php](https://github.com/phpbrew/phpbrew/blob/master/src/PhpBrew/Extension/ExtensionManager.php)
- **mlocati.** `IPE_DONT_ENABLE=1` installs without enabling, and `docker-php-ext-enable-<ext>` enables later — [README](https://github.com/mlocati/docker-php-extension-installer)
- **setup-php.** `:ext` disables an extension and its dependents. `none` disables all shared extensions. Windows enumerates `ext\*.dll` and reads their state with PhpManager `Get-PhpExtension` (Builtin, Enabled or other) — [README](https://github.com/shivammathur/setup-php), [add_extensions.ps1](https://github.com/shivammathur/setup-php/blob/main/src/scripts/extensions/add_extensions.ps1)
- **PIE.** There is no enable or disable command. `--skip-enable-extension` installs only. `pie show` lists PIE-installed extensions per target PHP, with an "installed but not enabled in INI file" status — [usage.md](https://github.com/php/pie/blob/1.6.x/docs/usage.md), [ShowCommand.php](https://github.com/php/pie/blob/1.6.x/src/Command/ShowCommand.php)
- **Laragon** toggles by commenting php.ini lines — [dev.to (community)](https://dev.to/dendihandian/installing-php-redis-extension-on-laragon-2mp3)

### Inferences — concrete lessons for `pvm ext install <ext> [--version=X.Y]`
1. **Resolve the target from PVM, not from PATH.** Always pass the version's own `php-config` (Unix) or `php.exe` (Windows) explicitly (PIE's `--with-php-config` / `--with-php-path`). Read the ABI tuple (API number, TS/NTS, VS compiler, arch, debug) from `php -i` "PHP Extension Build" of *that* binary, and print it in a header line such as PIE's "Target PHP installation: 8.5.10 nts … (from …)".
2. **Windows source order.** Try the PIE package's GitHub release asset first (accepting both `{ts}-{vs}` and `{vs}-{ts}` orders, and `x86_64` vs `x64`). Then try `downloads.php.net/~windows/pecl/releases/{ext}/{ver}/php_{ext}-{ver}-{X.Y}-{nts|ts}-vs{N}-{x64|x86}.zip`. Treat 404 as "not available for this ABI" and list the ABIs that *do* exist. There is no arm64 on PECL.
3. **Unix source order.** Use a prebuilt (`pre-packaged-binary`) asset only if libc, arch and TS match. Otherwise build with PIE. Before compiling, run a `check-build-tools`-style preflight and print the exact apt/dnf/brew command instead of silently using sudo.
4. **Never silently fall back from binary to source.** Rate limits caused this in PIE ([#701](https://github.com/php/pie/issues/701)). Offer `--binary-only` / `--source-only`, and honour `GITHUB_TOKEN`.
5. **Verify honestly.** Neither PECL DLLs nor PIE assets carry publisher checksums. Record the SHA-256 of the installed binary as PIE does. Refuse uninstall or overwrite if the file changed. Label installs "unverified source" per the glossary unless an attestation is found.
6. **Load-check before committing.** Write the ini line to a temp file in PVM's per-version scan dir, run `php -r 'return;'`, and compare stderr with the baseline (mlocati). Alternatively assert that the extension is in `php -m` (PIE). On failure, roll the ini back and keep or restore the previous binary (setup-php).
7. **Decide `zend_extension` vs `extension` from the binary.** Use the PIE `php-ext-zend` type, or look for the `zend_extension_entry` symbol (mlocati's `readelf` approach). Do not guess from the extension name.
8. **One ini file per extension in a PVM-owned scan dir, with an absolute `extension_dir`.** This avoids PIE #451 and #504. `pvm ext disable` renames to `.ini.disabled`, as phpbrew does, and keeps the binary. `pvm ext list` = `php -m` of that version plus a scan of `extension_dir` plus PVM's own install records (source, version, sha256).
9. **Windows dependency DLLs.** Place them next to `php.exe` (PIE) or symlink them there (setup-php), never via PATH. Detect a running PHP holding the DLL before replacing it ([#190](https://github.com/php/pie/issues/190)).
10. **Version syntax.** `--version=X.Y` should accept an exact version, a caret constraint and a stability floor (`^3`, `@stable`, `beta`), as all three ecosystems do. Map it to PIE's `vendor/pkg:^X.Y` and record the constraint for a future `pvm ext upgrade`.
11. **Name mapping.** Users type `redis`, but PIE wants `phpredis/phpredis`. Use PIE 1.6's extension→package map (or `pie search`) and show which package was picked.
12. **Exit codes and failure policy.** Default to fail-fast for a single-target CLI, unlike setup-php's warn-and-continue CI default. Use distinct exit codes for "not available for this ABI", "build tools missing", "built but failed to load" and "network or rate limit" (PIE's #416 shows this is a known pain).

### Gaps
- It was not tested whether PIE honours a `PHP_INI_SCAN_DIR` set only in the environment (as PVM would set it) when it picks its ini approach. Recommend a manual test.
