# Raw notes: tools survey (2026-11-10)

## PIE (php/pie): default branch 1.6.x, latest release 1.5.5 (2026-10-30)
- docs/usage.md @1.6.x: needs PHP >= 8.1 to run. Build tools: autoconf, automake, libtool, m4, make, gcc, plus `php-config`/`phpize`. Since 1.4.0 it "will attempt to detect and install the missing build tools", with an interactive prompt (or `--auto-install-build-tools`). It can also check and install system libraries for some extensions.
- Windows: "downloaded as DLL files and placed in the PHP extensions directory". Target selection: `--with-php-config` (Unix), `--with-php-path` (Windows), `--with-phpize-path`.
- Enabling: `phpenmod` (sury), `docker-php-ext-enable`, a new file in the "additional .ini file" path, or an append to php.ini. `--skip-enable-extension` turns it off.
- extension-maintainers.md: the `pre-packaged-binary` download method uses release assets named `php_{ext}-{ver}_php{X.Y}-{arch}-{os}-{libc}-{debug}-{ts}.{zip|tgz}`, for os in windows/darwin/linux and libc in glibc/musl. If no matching asset exists it falls back to compiling. The docs caution against it when the extension links dynamic libraries.
- Attestation: `gh attestation verify --owner php pie.phar` covers PIE itself only. Code search finds attestation code only in `src/SelfManage/Verify/*` (self-update). No verification of extension downloads was found.
- supported-extensions.md: xdebug/xdebug, phpredis/phpredis, pecl/pcov, imagick/imagick, mongodb/mongodb-extension, swoole/swoole, microsoft/sqlsrv, microsoft/pdo_sqlsrv, apcu/apcu, php-memcached/php-memcached. gRPC is listed **only as `bsn4/grpc`, a "drop-in Rust replacement for ext-grpc"**. The official grpc ext is not a PIE package.

## static-php-cli v3 source
- config/pkg/ext/ext-xdebug.yml: `build-static: false`, `build-shared: true`, source `type: pie`, repo xdebug/xdebug, Linux and Darwin. pcov is similar.
- src/Package/Target/php.php: `--build-shared` (`-D`). The comment says "shared-only extensions are built by phpize in their own source root".
- docs cli-reference: default ini path `/usr/local/etc/php`, `--with-config-file-path`, `--with-hardcoded-ini`. UPX is Linux/Windows only.
- docs faq: glibc builds load `.so` (self-build example). macOS `--build-shared=xdebug` gives `buildroot/modules/xdebug.so`, "same version and thread-safety type". Windows: "cannot load officially built dynamic extensions". It never mentions phpize/php-config/headers for prebuilts.

## Herd
- macOS docs (herd.laravel.com/docs/macos/technology/php-extensions.md): 55 bundled ext (Forge parity), static binaries. For extras: `brew install php`, then `pecl install X`, then add an absolute `.so` path in `~/Library/Application Support/Herd/config/php/<v>/php.ini`. So a Homebrew-built `.so` loads into Herd's static macOS PHP. This is the vendor's own proof that macOS static PHP loads foreign `.so`.
- Windows docs: download the NTS DLL from PECL and edit `%USERPROFILE%\.config\herd\bin\<v>\php.ini`.

## php.new
- php.new/install/linux (186 lines): downloads `https://download.herdphp.com/herd-lite/linux/{x64|arm64}/8.5/php`, composer, and the curl.se cacert into `~/.config/herd-lite/bin`. There is no checksum step. Single version 8.5.

## phpvm (Thavarshan)
- README: wraps Homebrew/apt/dnf/yum/pacman. `.phpvmrc` cd hook (`PHPVM_AUTO_USE`), composer.json fallback, `reinstall-extensions <from> [to]` diffs `php -m` (apt installs `phpX.Y-<ext>`, brew uses pecl, others list only, exit 3). Only self-update is checksum-verified.

## phpbrew
- Not archived, last push 2026-01-28, last release 2.2.0 on 2023-12-12. Builds from source into $HOME without root, with variants `+default +dbs`. Extension commands in source: Install, Enable, Disable, Config, Show, Clean, Known (src/PhpBrew/Command/ExtensionCommand/).

## php-build / phpenv / asdf-php / mise
- php-build: last push 2026-10-21. definitions/8.4.14 holds `install_package https://www.php.net/distributions/php-8.4.14.tar.bz2`, `install_xdebug "3.5.3"` and `enable_builtin_opcache`. It has `PHP_BUILD_INSTALL_EXTENSION` for PECL and plugins apc, composer, github, pie, xdebug, xhprof... Code search for sha256/gpg found only a patch filename, so **no tarball verification found**.
- php-build pie.sh: downloads `pie.phar` from GitHub latest into `$PREFIX/bin/pie`, with no attestation check.
- asdf-php: uses a pinned php-build submodule. README lists dev headers for libxml2, curl, icu, libzip, oniguruma, openssl, readline, plus autoconf, bison and re2c.
- mise registry/php.toml: `backends = ["vfox:jdx/vfox-php", "asdf:mise-plugins/asdf-php"]`. vfox-php builds from php-src release tarballs on Linux/macOS (`./buildconf --force`, configure, make), and its README does not mention Windows or checksums.

## Package managers
- shivammathur/homebrew-php Formula: php@5.6 … php@8.7, plus -zts, -debug and -debug-zts variants.
- shivammathur/homebrew-extensions grpc@8.3.rb: source from pecl.php.net with a sha256, plus **bottles** (ghcr.io/v2/shivammathur/extensions) for arm64 tahoe/sequoia/golden_gate, arm64_linux and x86_64_linux. The README lists grpc, xdebug, pcov, imagick, swoole, mongodb, redis, sqlsrv.
- ondrej/php PPA (Launchpad API getPublishedBinaries): php5.6-cli … php8.6-cli, and php5.6-grpc … php8.5-grpc are published. The per-package page shows Noble/Jammy.

## setup-php (README)
- Ubuntu: ppa:ondrej/php, with extensions from packages, PECL or git. macOS: shivammathur/homebrew-php plus homebrew-extensions. Windows: "extensions available on PECL which have the DLL binary".
- Syntax: `name-version`, `name-beta`, `:name` to disable, `none`. There are also `coverage: xdebug|pcov|none`, `ini-values`, and tools with `@sha256:` pin.

## docker-php-extension-installer
- `install-php-extensions gd xdebug` installs apt/apk deps, compiles, then removes build deps and caches. Debian and Alpine official php images only. Version syntax `xdebug-2.9.7`, `xdebug-^3@stable`.

## Windows PECL DLLs
- downloads.php.net/~windows/pecl/releases/grpc/1.85.0/ has php_grpc-1.85.0-{8.0..8.5}-nts-vs16/vs17-{x64,x86}.zip. The latest dirs are xdebug 3.5.3, redis 6.3.0, pcov 1.0.12, imagick 3.8.1. No checksum or signature files were seen in the listing.

## lerd (geodro/lerd)
- Podman-based Herd-like tool for Linux/macOS: `lerd use`, `lerd isolate`, `lerd xdebug on [version]` (rebuilds the FPM image). Seen via pkg.go.dev and search results only; the README was not read directly.
