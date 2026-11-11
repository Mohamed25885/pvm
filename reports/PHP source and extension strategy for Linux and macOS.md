# static-php covers basic PHP, but extra extensions need a real `php-config`

*Observed 2026-11-10. Facts marked **observed** were fetched or inspected that day (archives, ELF/Mach-O headers, GitHub API, Launchpad API, docs). **Inference** marks reasoning. **Unverified** marks anything not run or not confirmed in a primary source. No downloaded binary was executed. Raw notes are in `research_notes/PHP source and extension strategy for Linux and macOS/`.*

## TL;DR

static-php's `bulk` set is enough for a typical Composer, Laravel, Symfony or WordPress workflow. Its weak spots are the developer extensions (xdebug, pcov) and a handful of service clients (grpc, mongodb, sqlsrv, memcached, ldap).

No downloadable static-php archive ships `phpize`, `php-config` or headers. Each one contains a single `php` file. The musl build is UPX-packed and fully static, so it can never load a `.so`. The `gnu-bulk` and macOS builds are dynamically linked, export the Zend API and carry the ABI tag `API20240924,NTS`, so they *should* load a matching NTS `.so`. Herd relies on exactly that on macOS. That path is **not run-tested** here, and nothing upstream supports it.

Other version managers never mention a "no extensions" limit because every one of them gets PHP with a working `php-config`: from source (phpbrew, php-build, asdf, mise) or from a package manager (phpvm, setup-php). The static-PHP tools (Herd, php.new, lerd) all hit the limit and work around it.

**Recommended (1): static-php `bulk` for `pvm install`, plus `pvm ext install` backed by PIE against a PHP that has `php-config`.**
- On Windows, PIE uses `--with-php-path` and downloads prebuilt DLLs.
- On Linux and macOS, `pvm ext install` works for versions installed with `--from-source` (roadmap 3.2) or `pvm link`ed (3.3).
- For a static-php version, it fails with a clear message that names those two routes.
- PIE already does the hard parts: build-tool checks, system-library checks, and ini enabling.
- One gap: the official grpc extension is not a PIE package.

**Alternative (2): package-manager backends for extensions.** On macOS, `brew install shivammathur/extensions/grpc@8.3` installs *bottled* (prebuilt, sha256-pinned) extensions for PHP 5.6–8.7, with no sudo. On Ubuntu, ondrej/php publishes `php8.3-grpc` and similar packages for PHP 5.6–8.6, but needs sudo. This route gives the fastest and most complete `pvm ext install`, but it **reopens Q2**, because Q2 removes the apt and Homebrew installers.

**Alternative (3): `gnu-bulk` on Linux, macOS bulk, and PVM-built `.so` files.** PVM would fetch the GPG-verifiable php.net source of the exact patch, generate headers, and build the extension with the system compiler. This is the only way to keep prebuilt PHP *and* add extensions. It is unproven and would need a real Linux/macOS test first. It **reopens Q6**, because Q6 currently says musl.

## static-php `bulk` is enough for basic usage

The bulk and gnu-bulk 8.4 builds carry the same 56 named extensions, plus igbinary and msgpack through `--with-suggests` (**observed**) ([bulk README.txt](https://dl.static-php.dev/v3/php-bin/bulk/README.txt), [gnu-bulk build-manifest.json](https://dl.static-php.dev/v3/php-bin/gnu-bulk/build-manifest.json)).

| Need | In bulk | Notes |
|---|---|---|
| Composer (phar, zip, openssl, curl, mbstring, iconv) | yes | |
| Laravel/Symfony core (ctype, dom, fileinfo, filter, intl, session, tokenizer, xml*, bcmath, pcntl, posix, sodium, opcache) | yes | |
| MySQL (mysqli, pdo_mysql) and PostgreSQL (pgsql) | yes | |
| `pdo_sqlite`, `pdo_pgsql` | **not as extensions** | Swoole's hooks provide them. The hook "conflicts with the `pdo_sqlite` extension" ([extension notes](https://github.com/crazywhalecc/static-php-cli/blob/v3/docs/en/guide/extension-notes.md)). Whether plain `new PDO('sqlite:…')` works outside coroutines is **unverified**. The `common` set does ship real `pdo_sqlite` and `pdo_pgsql` ([common README.txt](https://dl.static-php.dev/v3/php-bin/common/README.txt)). |
| WordPress (gd, exif, imagick, zip, mysqli) | yes | |
| redis, apcu, imagick, swoole, event, protobuf, opentelemetry, soap, xsl | yes | |
| **xdebug, pcov** (debugging, coverage) | **no** | Can only be built as shared extensions: `build-static: false` ([ext-xdebug.yml](https://github.com/crazywhalecc/static-php-cli/blob/v3/config/pkg/ext/ext-xdebug.yml)) |
| grpc, mongodb, sqlsrv/pdo_sqlsrv, memcached, ldap, gettext, tidy, yaml, amqp | **no** | Not in any v3 set ([bulk README.txt](https://dl.static-php.dev/v3/php-bin/bulk/README.txt)) |

**Inference:** basic usage is covered, but `php artisan test --coverage` and step debugging are not. Laravel's default SQLite database depends on the swoole hook, so a smoke test on a real Linux machine should come before Q5 is closed.

Two details matter for PVM's layout (**observed** in the binaries' strings, [gnu-bulk archive](https://dl.static-php.dev/v3/php-bin/gnu-bulk/php-8.4.27-cli-linux-x86_64.tar.gz)):

- The compiled-in ini path is `/usr/local/etc/php` with the scan dir `/usr/local/etc/php/conf.d`, and the default `extension_dir` is `/lib/php/extensions/no-debug-non-zts-20240924`. PVM must point PHP at its own ini with `PHPRC` or `PHP_INI_SCAN_DIR`.
- Each archive is about 30–35 MB compressed and 33–103 MB unpacked.

## What the static-php prebuilts can actually do

PVM downloaded the 8.4.27 CLI archive from three sets. Each matched its `.sha256` sidecar. This is the first end-to-end sidecar match on record; the earlier report could not confirm one. Each archive contains **one file, `php`**, with no `phpize`, `php-config`, `include/`, `php.ini` or modules dir (**observed**).

| Build | Linking (observed) | Exports Zend API? | Can `dlopen` a `.so`? |
|---|---|---|---|
| bulk, Linux musl ([archive](https://dl.static-php.dev/v3/php-bin/bulk/php-8.4.27-cli-linux-x86_64.tar.gz)) | Fully static, no `PT_INTERP`, no `.dynsym`, **UPX 5.30-packed** | no | **No.** It has no dynamic loader, which matches the [FAQ](https://static-php.dev/en/faq/) |
| gnu-bulk, glibc 2.17 ([archive](https://dl.static-php.dev/v3/php-bin/gnu-bulk/php-8.4.27-cli-linux-x86_64.tar.gz)) | PIE, interpreter `ld-linux-x86-64.so.2`, NEEDED libc/libm/libdl/libpthread…, imports `dlopen@GLIBC_2.2.5` | yes, about 43k dynamic symbols, including `zend_parse_parameters` and `zend_register_functions` | **Probably** (inference, not run-tested) |
| bulk, macOS arm64 ([archive](https://dl.static-php.dev/v3/php-bin/bulk/php-8.4.27-cli-macos-aarch64.tar.gz)) | Links libSystem, libc++ and system frameworks. Export trie of 688 KB, 26,770 exported symbols | yes | **Probably.** Herd documents exactly this for its own static macOS PHP, by loading a Homebrew-built `.so` through an absolute `extension=` path ([Herd macOS docs](https://herd.laravel.com/docs/macos/technology/php-extensions.md)) |

Upstream documents `.so` loading only for self-builds: glibc with `SPC_TARGET=native-native-gnu.2.17`, and macOS with `--build-shared` ([FAQ](https://static-php.dev/en/faq/)). Two problems remain for the prebuilts (**inference**):

1. **No headers.** Building any extension needs `php-config` and the `main/php_config.h` that matches the build. PVM would have to rebuild these from php.net source with the same `./configure` flags. The archives do not record those flags: the binary's configure string is just `'./configure'`.
2. **Symbol interposition on gnu-bulk.** The binary also exports its bundled OpenSSL (`SSL_new`), libxml2, ICU, curl and sqlite. An extension that links the system's `libssl.so` could end up bound to PHP's copy instead. That is harmless when the versions match and a crash risk when they don't.

A bulk self-build with `spc` is not a cheap fallback either. The upstream CI's bulk jobs took about 40–60 min on Linux and 45–100 min on macOS, using prebuilt libraries (**observed**, [hosted run 41790368886](https://github.com/static-php/hosted/actions/runs/41790368886)).

## How other tools get PHP and add extensions

| Tool | PHP comes from | How users add an extension | Source |
|---|---|---|---|
| phpbrew | Source build into `$HOME`, no root | `phpbrew ext install/enable/disable` (phpize of the built PHP). Last release 2.2.0 (2023-12) | [repo](https://github.com/phpbrew/phpbrew), [ext commands](https://github.com/phpbrew/phpbrew/tree/master/src/PhpBrew/Command/ExtensionCommand) |
| phpenv + php-build | Source build from php.net tarballs | `PHP_BUILD_INSTALL_EXTENSION`, plus definitions that install xdebug by default and a `pie` plugin. No tarball checksum or GPG check found | [php-build](https://github.com/php-build/php-build), [8.4.14 definition](https://github.com/php-build/php-build/blob/master/share/php-build/definitions/8.4.14), [pie.sh](https://github.com/php-build/php-build/blob/master/share/php-build/plugins.d/pie.sh) |
| asdf-php | php-build (pinned submodule), with a long list of dev headers | `pecl` of the built PHP (implied: README only covers configure flags) | [asdf-php](https://github.com/asdf-community/asdf-php) |
| mise | `vfox:jdx/vfox-php` or the asdf plugin, both building from source | same as above | [registry/php.toml](https://github.com/jdx/mise/blob/main/registry/php.toml), [vfox-php](https://github.com/jdx/vfox-php) |
| phpvm (Thavarshan) | brew / apt / dnf / yum / pacman | `reinstall-extensions` diffs `php -m` (apt `phpX.Y-ext`, brew pecl) | [phpvm](https://github.com/Thavarshan/phpvm) |
| Herd (macOS, Windows) | Static binaries, 55 extensions | macOS: brew php, then pecl, then an absolute path in Herd's php.ini. Windows: download the NTS DLL | [macOS](https://herd.laravel.com/docs/macos/technology/php-extensions.md), [Windows](https://herd.laravel.com/docs/windows/technology/php-extensions.md) |
| php.new | Herd Lite single binary, PHP 8.5 only, from download.herdphp.com, **no checksum** | none | [install/linux](https://php.new/install/linux) |
| lerd | Rootless Podman images, with static-php prebuilts as a fallback | Extensions and Alpine packages declared once and baked into the images | [lerd README](https://github.com/geodro/lerd) |
| setup-php (CI) | Ubuntu ondrej PPA, macOS shivammathur taps, Windows php.net | packages, then PECL, then git. Windows uses "PECL which have the DLL binary" | [setup-php](https://github.com/shivammathur/setup-php) |
| docker-php-extension-installer | Official Docker php images | Compiles. Installs apt/apk deps, then removes build deps afterwards | [mlocati](https://github.com/mlocati/docker-php-extension-installer) |

## Options for adding extensions, compared

| Option | Install speed | System deps | sudo | Side-by-side | Can back `pvm ext install`? | Verification | Linux / macOS / Windows |
|---|---|---|---|---|---|---|---|
| **PIE** ([usage](https://github.com/php/pie/blob/1.6.x/docs/usage.md)) | Compile, minutes per extension (unverified figure). Windows DLLs are instant | autoconf, automake, libtool, m4, make, gcc, phpize/php-config. It offers to install them | Only to install build tools | Yes, via `--with-php-config` / `--with-php-path` | **Yes**, for any PHP with `php-config`; on Windows, any `php.exe` | Only PIE itself is attested; extension downloads are not | ✅ (source/link) / ✅ (source/link) / ✅ |
| **spc self-build** with extras baked in | About 40–100 min per PHP build ([CI run](https://github.com/static-php/hosted/actions/runs/41790368886)) | spc's toolchain, with prebuilt libs or source | No | Yes | Indirectly ("rebuild this version with grpc") | Partial input checks ([earlier report](Static%20PHP%20CLI%20release%20artifacts.md)) | ✅ / ✅ / ❌ (shared ext unsupported, [FAQ](https://static-php.dev/en/faq/)) |
| **From source** (php-build style, roadmap 3.2) | Full PHP build, minutes to tens of minutes (unverified) | Compiler plus about 10 `-dev` packages ([asdf-php](https://github.com/asdf-community/asdf-php)) | For deps only | Yes, in `$HOME` | **Yes** (then PIE or pecl) | php.net tarball GPG/SHA-256 possible; php-build does neither | ✅ / ✅ / ❌ |
| **Homebrew shivammathur taps** | **Bottles, seconds** ([grpc@8.3.rb](https://github.com/shivammathur/homebrew-extensions/blob/main/Formula/grpc@8.3.rb)) | Homebrew | No | php@5.6…8.7 ([Formula](https://github.com/shivammathur/homebrew-php/tree/main/Formula)) | Yes: `brew install shivammathur/extensions/<ext>@<X.Y>` | sha256 pinned in a git-tracked formula | ✅ (bottles for x86_64/arm64 Linux) / ✅ / ❌ |
| **ondrej/php PPA** | apt package, seconds | Ubuntu/Debian only | **Yes** | php5.6…8.6 CLI published ([Launchpad API](https://api.launchpad.net/1.0/~ondrej/+archive/ubuntu/php?ws.op=getPublishedBinaries&binary_name=-cli&status=Published)) | Yes: `apt install php8.3-grpc` (php5.6–8.5-grpc published, [Launchpad API](https://api.launchpad.net/1.0/~ondrej/+archive/ubuntu/php?ws.op=getPublishedBinaries&binary_name=grpc&status=Published)) | APT-signed repo | ✅ (Ubuntu/Debian) / ❌ / ❌ |
| **`pvm link`** to a system PHP (3.3) | Instant | Whatever the user already has | Up to the user | As provided | Delegates to that PHP's pecl/PIE/apt/brew | Up to the source | ✅ / ✅ / ✅ |
| **PECL Windows DLLs** | Instant | none | No | Per `X.Y-nts-vsNN-x64` | Yes (grpc 1.85.0 has 8.0–8.5 NTS x64, [listing](https://downloads.php.net/~windows/pecl/releases/grpc/1.85.0/)) | No checksum seen, so an **unverified install** by the glossary | — / — / ✅ |
| **gnu-bulk or macOS prebuilt + PVM-made headers** | One extension compile, after a one-time header generation | Compiler plus extension libs | No | Yes | Possibly | php.net source verifiable; the binary has only its sidecar | ⚠️ untested / ⚠️ untested / ❌ |

PIE has two limits for `pvm ext install grpc`:

- The only PIE gRPC package is `bsn4/grpc`, described as a "drop-in Rust replacement for ext-grpc". The official extension is not listed ([supported-extensions.md](https://github.com/php/pie/blob/1.6.x/docs/supported-extensions.md)).
- PIE's `pre-packaged-binary` naming does cover `linux`/`darwin` and `glibc`/`musl`, so extensions *could* ship prebuilt Linux/macOS `.so` files ([extension-maintainers.md](https://github.com/php/pie/blob/1.6.x/docs/extension-maintainers.md)). None of them fit a static-php build, which has no `php-config` for PIE to detect a target from (**inference**).

### How each option could back `pvm ext install grpc [--version=8.2]`

1. **Resolve the target** the way `pvm php` does: the project's `.pvm`, then the global version.
2. **Windows:** run PIE with `--with-php-path=<versions/X/php.exe>`, falling back to the PECL DLL URL pattern `php_<ext>-<v>-<X.Y>-nts-vs<NN>-x64.zip`. Then write `extension=` into PVM's per-version ini (roadmap 3.5).
3. **Linux/macOS, PHP with `php-config`** (source-built or linked): run PIE with `--with-php-config`. Alternatively use the package backend: `brew install shivammathur/extensions/grpc@X.Y` or `sudo apt install phpX.Y-grpc`. Use the latter only for linked brew or apt PHPs.
4. **Linux/macOS, static-php version:** stop with a message along the lines of "grpc isn't in this build; reinstall with `--from-source`, or `pvm link` a Homebrew/apt PHP". Alternative 3 would replace this step if a real test proves it works.

## Ideas for making version management easier

| Idea | Tool that does it |
|---|---|
| Auto-switch on `cd` through a shell hook, with a version file found by walking up parent dirs | phpvm `.phpvmrc`, `PHPVM_AUTO_USE` ([phpvm](https://github.com/Thavarshan/phpvm)) |
| Fall back to `composer.json` `require.php` when no version file exists | phpvm ([phpvm](https://github.com/Thavarshan/phpvm)) |
| Read `.tool-versions` / `.php-version`, so projects shared with asdf or mise users just work | asdf, mise ([mise registry](https://github.com/jdx/mise/blob/main/registry/php.toml)) |
| Carry extensions over to a new version by diffing `php -m` | phpvm `reinstall-extensions` ([phpvm](https://github.com/Thavarshan/phpvm)) |
| Install Composer (and PIE) with each version | php-build composer and pie plugins ([pie.sh](https://github.com/php-build/php-build/blob/master/share/php-build/plugins.d/pie.sh)), vfox-php ([vfox-php](https://github.com/jdx/vfox-php)) |
| Enable or disable extensions without uninstalling them | phpbrew `ext enable/disable` ([commands](https://github.com/phpbrew/phpbrew/tree/master/src/PhpBrew/Command/ExtensionCommand)), setup-php `:ext` and `none` ([setup-php](https://github.com/shivammathur/setup-php)) |
| One-flag coverage driver switch: xdebug, pcov or none | setup-php `coverage:` ([setup-php](https://github.com/shivammathur/setup-php)), lerd `xdebug on` ([lerd](https://github.com/geodro/lerd)) |
| Pin extension versions inline (`xdebug-3.3.0`, `xdebug-^3@stable`) | setup-php, docker-php-extension-installer ([mlocati](https://github.com/mlocati/docker-php-extension-installer)) |
| `ini-values` set from the command line | setup-php ([setup-php](https://github.com/shivammathur/setup-php)) |
| Check build tools and system libraries, then offer to install them (`check-build-tools`) | PIE ([usage](https://github.com/php/pie/blob/1.6.x/docs/usage.md)) |
| Remove build-only deps after compiling | docker-php-extension-installer ([mlocati](https://github.com/mlocati/docker-php-extension-installer)) |
| Hash-pinned tool downloads (`tool:1.2.3@sha256:…`) | setup-php ([setup-php](https://github.com/shivammathur/setup-php)) |
| One-line bootstrap of PHP plus Composer | php.new ([install/linux](https://php.new/install/linux)) |
| Aliases, `ls-remote`, `install latest-remote` | phpvm ([phpvm](https://github.com/Thavarshan/phpvm)) |

## What this means for decided items

- **Q2** (static-php on Linux/macOS; remove the apt and Homebrew installers). Homebrew's shivammathur taps are the only source found with *prebuilt, hash-pinned* extensions for every PHP version, and with no sudo. If one-command `pvm ext install` matters, keeping a Homebrew or apt backend (as an extension backend or through `pvm link`) is new information against roadmap 3.4. **Not decided here.**
- **Q5** (`bulk` by default). It is confirmed adequate for basic usage. New facts: `bulk` has no real `pdo_sqlite`/`pdo_pgsql` (swoole hooks stand in, untested), xdebug and pcov can never be static, and `common` does have real `pdo_sqlite`/`pdo_pgsql`. **Not decided here.**
- **Q6** (musl over gnu-bulk). New facts: the musl binary is UPX-packed and fully static, so it can never load an extension. gnu-bulk is a dynamic glibc PIE that exports the Zend API with the same ABI tag. If the extension path (alternative 3) is wanted, only gnu-bulk keeps it open. **Not decided here.**

## Open questions for the user

1. Must `pvm ext install` work for the *default* Linux/macOS install? If yes, the choices are alternative 2 (brew/apt, which reopens Q2) or alternative 3 (gnu-bulk, which needs a real-machine test and reopens Q6). If no, recommendation 1 works as is.
2. Is a C toolchain an acceptable requirement for `pvm ext install` on Linux/macOS? PIE, from-source builds and alternative 3 all need one. Only brew bottles and apt avoid it.
3. Should someone run a concrete test on a Linux and a Mac machine? The test: build `redis` or `pcov` against php.net 8.4.27 headers, then `-d extension=…` into the gnu-bulk and macOS binaries. Also: does `new PDO('sqlite::memory:')` work in bulk?
4. Is grpc a must? The official extension is not on PIE, but it is available as PECL Windows DLLs, Homebrew bottles and ondrej packages.
5. Should Windows `pvm ext install` accept PECL DLLs, which have no published checksum, as *unverified installs* behind `--allow-unverified` (the Q1 rule)? Or should it prefer PIE's GitHub-hosted binaries?
