# Ways to get side-by-side PHP versions on Linux, macOS and Windows, and what building from source costs

*Observed 2026-11-10. **Observed** = fetched or inspected that day (GitHub API, Launchpad/repo indexes, archive listings, ELF headers). No downloaded binary was executed. This builds on two earlier reports, `reports/PHP source and extension strategy for Linux and macOS.md` and `reports/Static PHP CLI release artifacts.md`. Their findings are summarized here, not redone: static-php has no phpize, Homebrew extension bottles, ondrej grpc, PIE, Herd and php.new.*

## Q1: Prebuilt PHP. Which builds are relocatable, and which ship phpize, php-config and headers?

### Takeaway
**pkgx** is the one relocatable, no-sudo, prebuilt PHP for Linux and macOS that ships `phpize`, `php-config`, `pecl` and headers. It covers PHP 7.4–8.5 and publishes a sha256 and a GPG `.asc` per bottle. But it depends on about 30 sibling pkgx library bottles, and PHP 8.4 links OpenSSL 1.1.

shivammathur/php-builder does ship full dev tools, but it is **not relocatable**: it extracts into `/` with sudo and expects Ubuntu or Debian. windows.php.net is the best channel overall: relocatable zips, a sha256 for each in `releases.json`, and a `devel_pack` for building extensions.

### Cited Findings
**windows.php.net**
- `releases.json` (now served from `downloads.php.net/~windows/releases/releases.json` after a 302) lists, for each build key such as `ts-vc15-x64`: the `zip` with a `sha256`, a `debug_pack`, and a `devel_pack` with a `sha256`. Example: 7.4.33 `php-devel-pack-7.4.33-Win32-vc15-x64.zip`, 1.08 MB (**observed**). — [releases.json](https://downloads.php.net/~windows/releases/releases.json)
- Windows extension binaries are PECL DLLs per `X.Y-nts-vsNN-x64`, with no checksum seen (earlier report). — [PECL listing](https://downloads.php.net/~windows/pecl/releases/grpc/1.85.0/)

**static-php-cli (dl.static-php.dev v3)**
- Each archive holds a single `php` file. There is no `phpize`, no `php-config` and no headers. The musl build is fully static and UPX-packed. (Earlier report.) — [bulk README](https://dl.static-php.dev/v3/php-bin/bulk/README.txt)

**Herd Lite / php.new**
- Herd Lite is a single static binary with PHP 8.5 only and no checksum (earlier report). — [php.new install/linux](https://php.new/install/linux)

**shivammathur/php-builder** ("Build PHP 5.6 to 8.7", pushed 2026-11-06)
- Ships one GitHub release per PHP minor. The 8.4 release has `php_8.4+{debian11,12,13,ubuntu22.04,24.04,26.04}[_arm64].tar.{xz,zst}`, about 20–22 MB each, plus dbgsym tarballs of about 320 MB (**observed**). — [releases/tag/8.4](https://github.com/shivammathur/php-builder/releases/tag/8.4)
- The tarball is a Debian-style root tree: `./etc/php/8.4`, `./usr/lib/php/20240924/*.so`, and man pages for `phpize8.4.1` and `php-config8.4.1`. It bundles about 90 shared extensions, including grpc, redis, imagick, pdo_sqlsrv and rdkafka (**observed** in a partial listing; the listing was truncated before `usr/bin`). — [php_8.4+ubuntu24.04.tar.xz](https://github.com/shivammathur/php-builder/releases/download/8.4/php_8.4+ubuntu24.04.tar.xz)
- `install.sh` runs `sudo tar ... -C /`, installs about 70 apt `-dev` and runtime packages, and registers `update-alternatives` for `php-config`, `phpize`, `php` and `phpdbg`. Per-version pecl is configured through `php-config$version` (**observed**, lines 108, 155–159, 179, 217). — [install.sh](https://github.com/shivammathur/php-builder/releases/download/8.4/install.sh)
- No checksum or signature asset was seen in the 8.4 release asset list (**observed**). — [releases/tag/8.4](https://github.com/shivammathur/php-builder/releases/tag/8.4)

**pkgx (dist.pkgx.dev)**
- Prebuilt versions for linux/x86-64: 7.4, 8.0, 8.1, 8.2, 8.3, 8.4 and 8.5, with 8.4.27 the latest 8.4 and 8.5.12 on darwin/aarch64 (**observed**). — [versions.txt linux](https://dist.pkgx.dev/php.net/linux/x86-64/versions.txt), [darwin](https://dist.pkgx.dev/php.net/darwin/aarch64/versions.txt)
- `v8.4.27.tar.xz` is 17.8 MB. Its `.sha256sum` matched the download, and a `.asc` signature exists (HTTP 200) (**observed**). — [v8.4.27.tar.xz.sha256sum](https://dist.pkgx.dev/php.net/linux/x86-64/v8.4.27.tar.xz.sha256sum)
- The bottle contains `bin/php`, `phpize`, `php-config`, `pecl`, `pear`, `php-cgi`, `phpdbg`, `sbin/php-fpm`, `include/main/php_config.h` and `lib/php/20240924/opcache.so` (**observed**). — same archive
- The bottle is relocatable: `php-config` uses `prefix="$(dirname "$(dirname "$0")")"`, and the ELF RPATH is all `$ORIGIN/../../../<pkg>/vN/lib` (**observed**).
- It is **not self-contained**. It has about 30 NEEDED libraries from sibling pkgx bottles, including `libssl.so.1.1` (OpenSSL 1.1, which is EOL), ICU 73, libxml2, libpq and libsodium.so.23 (**observed**).
- Possible defects (**observed**, effect not tested):
  - `extension_dir` points at `${prefix}/../../php.net/v8.4.27+brewing/lib/php/20240924`, which is a build-time path.
  - `include_dir` is `${prefix}/include/php`, but the archive has no `include/php/` entries.
- The recipe lists the dependencies and patches `phpize`/`php-config` to use pkgx's sed. — [pantry php.net/package.yml](https://github.com/pkgxdev/pantry/blob/main/projects/php.net/package.yml)

**conda-forge `php`**
- Builds from the php.net tarball with a pinned sha256. Configures with `--prefix=$PREFIX`, which conda relocates. The recipe is at 8.5.12 (**observed**). — [recipe.yaml](https://github.com/conda-forge/php-feedstock/blob/main/recipe/recipe.yaml), [build.sh](https://github.com/conda-forge/php-feedstock/blob/main/recipe/build.sh)
- Versions published: 8.5 for linux-64, linux-aarch64, osx-64, osx-arm64 and win-64. Older versions are mostly linux-only: 8.1 (linux-64, aarch64, ppc64le, osx-64), 8.0, 7.4 and 7.3 (**observed**). There is no 8.2, 8.3 or 8.4. — [anaconda.org API](https://api.anaconda.org/package/conda-forge/php)

**Nix**
- `generic.nix` moves `phpize` and `php-config` into a separate `dev` output, and offers `php.buildEnv` / `withExtensions` (**observed**). — [generic.nix](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/interpreters/php/generic.nix)
- The exact attribute set (php82…php85) is **unverified**: the version file path returned a 404.

**Homebrew**
- Homebrew core has `php` (8.5.12, not keg-only) and `php@8.1` to `php@8.4`, all keg-only (**observed**). — [formulae.brew.sh php@8.4](https://formulae.brew.sh/api/formula/php@8.4.json)
- The `shivammathur/php` tap formula `php@8.3` is `keg_only :versioned_formula`. Its bottles carry sha256 for arm64 macOS and for x86_64 and arm64 Linux. It moves pecl output to `HOMEBREW_PREFIX/lib/php/pecl/<api>` and keeps a per-formula `phpize` (**observed**, lines 38–46, 234–293). — [php@8.3.rb](https://github.com/shivammathur/homebrew-php/blob/main/Formula/php@8.3.rb)

### Inferences
- The only prebuilt Linux/macOS channels with a usable `php-config` are pkgx, conda-forge (but only 8.5 on macOS), Homebrew/tap bottles (under the brew prefix), Nix (under `/nix`), and distro packages.
- For PVM, pkgx bottles would mean resolving and downloading the pkgx dependency closure into a pkgx-shaped tree, in effect reimplementing pkgx.
- Relocating Homebrew bottles outside the brew prefix is not supported in general. **Unverified**; not tested.

### Gaps
- php-builder: the `usr/bin` entries were not seen, because the download was truncated by a timeout. That `phpize8.4` ships is inferred from the man pages and `install.sh`.
- No other relocatable Linux/macOS prebuilt with headers was found, under mise/aqua/ubi, Bitnami or "cli-php". These were not searched exhaustively.

## Q2: Package managers. Which allow side-by-side versions and per-version pecl/phpize?

### Takeaway
All the major third-party repos install side-by-side with a `-dev`/`-devel` package for each version. Most also ship prebuilt extension packages. Every one of them needs sudo and a supported distro.

### Cited Findings
- **ondrej/php (Ubuntu)**: php5.6…8.6 CLI and grpc packages are published (earlier report). — [Launchpad API](https://api.launchpad.net/1.0/~ondrej/+archive/ubuntu/php?ws.op=getPublishedBinaries&binary_name=-cli&status=Published)
- **packages.sury.org (Debian trixie amd64)**: `phpX.Y-cli` and `phpX.Y-dev` exist for every version from 5.6 through 8.6. The repo key `apt.gpg` is served (**observed**). — [Packages.gz](https://packages.sury.org/php/dists/trixie/main/binary-amd64/Packages.gz)
- **Remi**:
  - The wizard offers "Multiple versions simultaneously" as an install mode. It covers RHEL/EL 8–10 and Fedora 43–45, with PHP 7.4–8.5 plus 8.6.0RC5 (**observed**). — [Remi wizard](https://rpms.remirepo.net/wizard/)
  - The EL9 "safe" repo has SCL packages for php74 through php86, for example `php84-php-cli-8.4.27`, `php84-php-devel`, `php84-php-pecl-xdebug3-3.5.3`, `php84-php-pecl-grpc-1.85.1` and `php84-php-pecl-redis6-6.3.0` (**observed**). — [EL9 safe repo index](https://rpms.remirepo.net/enterprise/9/safe/x86_64/)
- **Homebrew**: versions are keg-only and side-by-side; pecl goes to a per-API dir (Q1). Extension bottles come from `shivammathur/extensions` (earlier report). — [php@8.3.rb](https://github.com/shivammathur/homebrew-php/blob/main/Formula/php@8.3.rb)
- **Nix**: per-version derivations, with phpize in the `dev` output (Q1). — [generic.nix](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/interpreters/php/generic.nix)
- **Alpine, Arch AUR, MacPorts**: **not researched** in this pass.

### Inferences
- Across ondrej, sury and Remi, "side-by-side plus per-version pecl" is a solved problem, but always with root and only on Debian-family or RHEL-family distros. A `pvm link` to these is cheap. A built-in installer is not, because of sudo.

### Gaps
- Alpine community repos ship only 1–2 PHP versions. That is unverified this pass.
- MacPorts `php8x` ports were not checked.

## Q3: Source builds. Build time, dependencies, failure modes, and verification

### Takeaway
A CLI-focused PHP build takes about **5–9 minutes** on a 4-vCPU CI runner, including dependency install, and will be longer on a laptop's first run. It needs a compiler plus about 15–20 `-dev` packages, which takes sudo on Linux or Homebrew on macOS.

macOS builds are the main failure source: Homebrew paths for bzip2, iconv, openssl and icu, BSD grep, and spaces in the path. php.net tarballs can be fully verified with a sha256 from the JSON API and a GPG `.asc`.

### Cited Findings
**Build times**
- docker-library/php CI, 2026-11-08: the `8.4.27-cli-trixie` job took about 5m47s, `cli-bookworm` (8.4.28RC1) about 5m45s, and `8.4.27-cli-alpine3.24` about 9m0s. These jobs cover image build plus tests (**observed** from job timestamps). — [run 42429684274](https://github.com/docker-library/php/actions/runs/42429684274)
- php-builder CI, 2026-11-09: one SAPI per job (cli, fpm, embed, ...) of PHP 8.7 took about 7–10 min each on `ubuntu-24.04` runners. Each job includes installing about 70 dev packages and building a large extension set (**observed**). — [run 42539085930](https://github.com/shivammathur/php-builder/actions/runs/42539085930)
- A full static-php `bulk` self-build takes 40–100 min (earlier report). — [hosted run](https://github.com/static-php/hosted/actions/runs/41790368886)

**Dependency lists** (from the asdf-php README)
- Ubuntu/Debian: `autoconf bison build-essential re2c pkg-config libbz2-dev libcurl4-openssl-dev libicu-dev libjpeg-dev libpng-dev libonig-dev libreadline-dev libsqlite3-dev libssl-dev libxml2-dev libzip-dev zlib1g-dev libxslt1-dev libtidy-dev`. Optional: gmp, sodium, libpq, freetype.
- Arch: an equivalent `pacman` list.
- Fedora 44: an equivalent `-devel` list.
- macOS: `brew install autoconf bison bzip2 icu4c libedit libiconv libjpeg libpng libxml2 libxslt libzip openssl@3 pkg-config re2c zlib`.
- Source: [asdf-php README](https://github.com/asdf-community/asdf-php)
- The docker-library Dockerfile installs `$PHPIZE_DEPS` via apt. — [8.4/bookworm/cli/Dockerfile](https://github.com/docker-library/php/blob/master/8.4/bookworm/cli/Dockerfile)

**Failure modes in issue trackers**
- php-build:
  - #784 "All versions of PHP fail to install on macOS" (2024-10). Errors include "Please reinstall the BZip2 distribution", a `test:` error from a space in "Library/Application Support", and `grep -P` failing under BSD grep.
  - Other titles: #796 (ICU 74 / libxml2 2.12 patches for PHP 8.0 on macOS), #788 (7.4.33 fails), #774 (8.2.18 on Manjaro), #800 (an abort with bash 5.3).
  - Sources: [#784](https://github.com/php-build/php-build/issues/784), [issues](https://github.com/php-build/php-build/issues)
- asdf-php: #94 (7.4.23 on Apple M1), #171 (failure with libxml2 2.12.3), #88 (Apple Silicon). #201 (2026-01) is a user guide that needs 20 brew packages and six `--with-*=$(brew --prefix …)` flags. — [asdf-php #201](https://github.com/asdf-community/asdf-php/issues/201), [#171](https://github.com/asdf-community/asdf-php/issues/171)
- phpbrew: #1366 (7.4.33 on Mac, 2024), #1329 (openssl on macOS), #1248 (M1), #1392 (Apache2, 2025), #1337 (missing `libsystemd`). — [phpbrew issues](https://github.com/phpbrew/phpbrew/issues?q=macos+openssl)
- Old PHP fails against new system libraries:
  - pkgx pins `libsodium <1.0.19` and `libxslt <1.1.43`. — [pantry package.yml](https://github.com/pkgxdev/pantry/blob/main/projects/php.net/package.yml)
  - conda-forge patches an FTP test cert that expired on 2026-07-23. — [recipe.yaml](https://github.com/conda-forge/php-feedstock/blob/main/recipe/recipe.yaml)

**Verification**
- The php.net JSON API (`releases/index.php?json&version=8.4`) returns a `sha256` for each tarball. For 8.4.27 (21 Oct 2026), the tar.xz value is `dcf93923…d3f0` (**observed**). — [php.net releases JSON](https://www.php.net/releases/index.php?json&version=8.4)
- `php-8.4.27.tar.xz.asc` and `php-keyring.gpg` are both served (HTTP 200) (**observed**). — [php.net distributions](https://www.php.net/distributions/php-8.4.27.tar.xz.asc)
- docker-library pins `PHP_SHA256` and three `GPG_KEYS`, then runs `gpg --batch --verify php.tar.xz.asc` (**observed**). — [Dockerfile](https://github.com/docker-library/php/blob/master/8.4/bookworm/cli/Dockerfile)
- php-build does neither check (earlier report).

### Inferences
**"Why not just build PHP from source from the start?"**

- **What it fixes.** Every install gets a matching `php-config`, so `pvm ext install` (PIE/pecl) always works. Supply-chain trust reduces to php.net GPG plus sha256, which is better than any Linux/macOS prebuilt channel except pkgx's `.asc`.
- **What it costs.**
  1. Each install takes about 5–10 min of CPU, versus seconds for a download. N versions multiplies that.
  2. A C toolchain plus about 15–20 `-dev` packages are required. On Linux that needs sudo, which conflicts with a no-sudo user-space tool. On macOS it needs Homebrew.
  3. PVM would inherit the long-tail breakage seen in all four source-based tools: macOS library paths, old PHP against new libxml2/ICU/OpenSSL 3, and toolchain changes such as bash 5.3. That is a permanent patch-maintenance burden, in practice reimplementing php-build's per-version patch sets.
  4. Windows cannot use this path in practice (MSVC SDK). It does not need it either: zips plus the `devel_pack` already cover extensions.
- **Better default.** Prebuilt by default (static-php, or windows.php.net on Windows), with source build as an opt-in for users who need extensions. This matches what the evidence shows every successful tool doing:
  - Herd, php.new and setup-php all prebuild.
  - Only phpbrew, php-build, asdf and mise build, and they carry the issue backlog above.
- **Middle ground worth testing.** pkgx bottles are prebuilt, relocatable, include phpize and are GPG-signed. They cost a dependency closure, OpenSSL 1.1, and possibly broken `extension_dir`/`include_dir` paths, both **untested**.

### Gaps
- No measured laptop or first-run time for php-build, phpbrew or mise. The figures above are CI job durations, which include setup and tests and run with a warm apt mirror.
- Total build-dependency install size was not measured.
- Whether the pkgx `php-config` paths actually break `phpize` builds was not tested, because nothing was executed.
- The mise `vfox-php` dependency list and its issues were not re-checked in this pass. It is covered in the earlier report as a source build.
