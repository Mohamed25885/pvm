# Per-version PHP folders (hosting panels, distros, dev stacks) and how version managers adopt existing installs

Researched 2026-11-10. Claims marked **[unverified]** come from memory or secondary sources that I could not confirm against a primary page in this pass.

## 1. Plesk: per-version handler folders and PECL

### Takeaway
Plesk ships each PHP version as its own package tree under `/opt/plesk/php/X.Y/` with its own `bin/pecl`. The supported way to add an extension today is a handler-scoped CLI (`plesk bin php_handler --extension-install <ext> -id <handler>`), which wraps per-version PECL. An extension installed for one handler is visible to every handler that shares the same PHP binary.

### Cited Findings
- Since Plesk 18.0.48, extensions are installed with `plesk bin php_handler --extension-install <name> -id <handler id>`. Handler IDs come from `plesk bin php_handler --list`. Example: `--extension-install msgpack -id plesk-php83-fpm`. Version pins look like `msgpack-2.2.0` or `msgpack-beta`, and removal is `--extension-uninstall`. — [Plesk docs: Installing PHP extensions from PECL](https://docs.plesk.com/en-US/obsidian/administrator-guide/web-hosting/php-management/plesk-for-linux-installing-php-extensions-from-pecl.80036/)
- The GUI path is Tools & Settings > PHP Settings > (handler) > Manage PECL Packages. It needs PHP handler 7.3 or later. Installed extensions are enabled by default. An extension installed for one handler is available to other handlers that use the same PHP version and binary. — [same page](https://docs.plesk.com/en-US/obsidian/administrator-guide/web-hosting/php-management/plesk-for-linux-installing-php-extensions-from-pecl.80036/)
- The older manual route has three steps. First install the matching `plesk-phpXY-dev` package (for example `plesk-php70-dev`), which provides phpize. Then run `/opt/plesk/php/X.Y/bin/pecl install <ext>` and add an `extension=` ini to that version's `php.d` directory. Finally run `plesk bin php_handler --reread`. — search summary of [Plesk KB 12377140315671](https://support.plesk.com/hc/en-us/articles/12377140315671) (the KB returned 403 to direct fetch, so these specific steps are **[unverified from primary]**) and the [Plesk forum](https://talk.plesk.com/threads/cannot-install-any-pecl-module-php-8-0.367064/latest)
- A user reported that `/opt/plesk/php/8.2/bin/pecl install memcached` built the extension against the wrong PHP version, and the `php_handler --extension-install` command fixed it. — [talk.plesk.com thread (via search)](https://talk.plesk.com/threads/how-to-install-memcache-pecl-extension-for-php-not-memcached.367283/latest) (user report)
- A forum report gives `phpize: not found` as the usual symptom when the `-dev` package is missing. A noexec `/tmp` breaks PECL, and the fix is `pear config-set temp_dir /var/tmp`. — [talk.plesk.com](https://talk.plesk.com/threads/cannot-install-any-pecl-module-php-8-0.367064/latest) (user report)
- **[unverified]** The layout is `/opt/plesk/php/X.Y/{bin/php, bin/php-cgi, bin/pecl, bin/phpize, bin/php-config}`, with `/opt/plesk/php/X.Y/etc/php.ini`, `/opt/plesk/php/X.Y/etc/php.d/*.ini`, and modules in `/opt/plesk/php/X.Y/lib64/php/modules` (RPM) or `lib/php/modules` (deb). This matches common forum usage, but I did not fetch a page that states it.

### Inferences
- Plesk's model is the template PVM is after: one prefix per version, with that version's own `pecl`/`phpize`/`php-config` all pointing back into it. Its own users still hit "pecl built for the wrong version", so PVM should invoke the version's own `bin/pecl` or `php-config` by absolute path and never rely on PATH.
- Plesk splits headers into a `-dev` package. A "plug in a folder" feature should check that `phpize`/`php-config` and `include/php` exist before it promises that `pecl install` will work.

### Gaps
- Plesk for Windows: I found nothing primary on where it puts PHP versions or how PECL/DLL extensions are added there. **[unverified]** It is believed to use `%plesk_dir%\Additional\PleskPHPxx\` folders.

## 2. Peers: cPanel EA4, DirectAdmin, Remi SCL, ondrej/Debian, Homebrew, Laragon/XAMPP/WAMP

### Takeaway
Every mature multi-version system gives each version its own prefix and its own pecl/phpize/php-config. The exception is Debian/ondrej. It shares one `pecl` and uses suffixed binaries (`php8.3`, `phpize8.3`, `php-config8.3`), so per-version PECL needs `-d php_suffix=X.Y`. Homebrew is the closest Unix analogue to "self-contained folder plus a shared, persistent extension dir".

### Cited Findings
**cPanel EasyApache 4**
- Each installed PHP version has its own PECL at `/opt/cpanel/ea-php##/root/usr/bin/pecl`, used as `.../pecl install $module`. — [cPanel support: Install PECL extensions using the CLI](https://support.cpanel.net/hc/en-us/articles/17846214073495-Install-PECL-extensions-using-the-CLI) (via search summary)
- `/usr/local/bin/ea-php##` is a symlink to that version's php-cli, and `/usr/bin/ea-php##` is a symlink to its php-cgi. The ini scan dir is `/opt/cpanel/ea-php##/root/etc/php.d/`. — [cPanel docs: EA4 File System Layout](https://docs.cpanel.net/ea4/basics/easyapache-4-file-system-layout/)
- A third-party guide enables an extension by writing `extension=x.so` into `/opt/cpanel/ea-phpXX/root/etc/php.d/x.ini`. — [Micron21 KB](https://support.micron21.com/kb/articles/how-to-install-a-php-extension-using-pecl)
- **[unverified]** The header and phpize package is `ea-phpXX-php-devel`.

**Remi SCL (RHEL/Fedora)**
- SCL packages install "beside the default system version (in /opt/remi)". Several versions can be installed at once. The `php*-syspaths` package exposes one version at `/usr/bin/php`. Remi ships NTS builds only. — [Remi FAQ](https://blog.remirepo.net/pages/English-FAQ)
- **[unverified]** The tree is `/opt/remi/phpXY/root/usr/bin/{php,pecl,phpize,php-config}` with config in `/etc/opt/remi/phpXY/php.ini` and `php.d/`. Headers come from `phpXY-php-devel`, and the per-version pecl comes from `phpXY-php-pear` (run as `phpXY-pecl` or via `scl enable phpXY`).

**ondrej PPA / Debian**
- Binaries are `/usr/bin/php5.6` … `/usr/bin/php7.3`, with build tools `/usr/bin/phpize7.3` and `/usr/bin/php-config7.3`. Module ini lives at `/etc/php/X.Y/mods-available/<ext>.ini` and is turned on with `phpenmod -v X.Y -s cli <ext>` (off with `phpdismod`). The default comes from `update-alternatives --set php /usr/bin/phpX.Y`. — [mwop.net: Managing multiple PHP versions via ondrej/php](https://mwop.net/blog/2019-04-30-ondrej-multiversion-php.html)
- Only one PECL binary is installed. Per-version builds use `pecl -d php_suffix=7.3 install swoole`, and `pecl uninstall -r swoole` then clears PECL's shared registry so the next version can install it too. — [mwop.net](https://mwop.net/blog/2019-04-30-ondrej-multiversion-php.html); same approach in [besthub.dev](https://besthub.dev/articles/how-to-install-and-uninstall-pecl-extensions-for-multiple-php-versions-97cd19f50f61)
- Debian's phpize derives `phpdir` from `$prefix/lib/php/<DEBIAN_PHP_API>/build`. — [sources.debian.org phpize.m4 (search summary)](https://sources.debian.org/src/php8.4/8.4.16-1/scripts/phpize.m4)
- **[unverified]** Extensions go in `/usr/lib/php/<ZEND_MODULE_API>/` (for example `20230831` for 8.3), and SAPI-specific `conf.d` dirs are `/etc/php/X.Y/{cli,fpm,apache2}/conf.d` (symlinks created by phpenmod). The phpenmod script is in [php-defaults](https://sources.debian.org/src/php-defaults/96/phpenmod), but I did not fetch it.

**Homebrew (shivammathur/homebrew-php `php@8.3`)**
- The build uses `--prefix=#{prefix}` (the Cellar keg) with `--with-config-file-path=etc/php/<ver>` and `--with-config-file-scan-dir=etc/php/<ver>/conf.d`. Config therefore lives outside the keg, under `$(brew --prefix)/etc/php/8.3/`. — [Formula php@8.3.rb](https://raw.githubusercontent.com/shivammathur/homebrew-php/main/Formula/php@8.3.rb)
- `php-config` is rewritten so its extension dir points at `prefix/pecl`. That is a symlink to `HOMEBREW_PREFIX/lib/php/pecl`, which survives upgrades. The shipped php.ini sets `extension_dir = "$HOMEBREW_PREFIX/lib/php/pecl/<api>"`. — [same formula](https://raw.githubusercontent.com/shivammathur/homebrew-php/main/Formula/php@8.3.rb)
- Post-install configures that version's pear/pecl with `config-set php_ini`, `php_dir` (`share/pear@8.3`), `ext_dir` (from `php-config --extension-dir`), `bin_dir` and `php_bin`. As a result, `$(brew --prefix php@8.3)/bin/pecl install x` targets only 8.3. — [same formula](https://raw.githubusercontent.com/shivammathur/homebrew-php/main/Formula/php@8.3.rb)

**Laragon / XAMPP / WAMP (Windows)**
- Laragon: "download and extract the desired PHP versions into the `bin\php` directory", then switch with Menu > PHP > Version. — [Laragon docs: Multi-Version](https://laragon.org/docs/multi-version)
- Community guides name each subfolder after the zip (for example `C:\laragon\bin\php\php-8.x-Win32-vs17-x64`), and Laragon uses the folder name as the identifier. — [dev.to](https://dev.to/dendihandian/adding-php-74-to-laragon-4ik1); [Medium](https://medium.com/@oluwaseye/add-different-php-versions-to-your-laragon-installation-d2526db5c5f1) (secondary)
- **[unverified]** WampServer uses `wamp64\bin\php\phpX.Y.Z\` with `ext\` and two inis (`php.ini` for CLI and `phpForApache.ini`). XAMPP has a single `xampp\php\`.
- DirectAdmin CustomBuild: **[unverified]** It uses `/usr/local/phpXY/bin/{php,pecl,phpize}` with config under `/usr/local/phpXY/lib/php.ini` and `php.conf.d/`. I fetched no primary doc.

### Inferences
- Windows zips are self-contained already: `php.exe`, `ext\`, `php.ini-*`, and on TS builds `php8ts.dll` versus `php8.dll` on NTS. They are relocatable. The CLI reads `php.ini` from the exe's directory **[unverified: php.net ini search-order page not fetched]**. Windows has no pecl or phpize, so "pecl install" there means placing a downloaded DLL that matches version, TS/NTS, VS runtime and arch into `ext\`.
- On Unix, the Homebrew pattern is "versioned prefix plus pear config-set pointing at that prefix", and it is the cleanest to copy.

### Gaps
- I did not fetch Remi's per-version paths, the ea-php devel package name, DirectAdmin's docs, or WAMP/XAMPP docs from primary pages.

## 3. How version managers adopt or "plug in" an existing install, and how they validate it

### Takeaway
Most tools adopt in one of two ways. Some symlink an external prefix into their versions dir (rbenv, mise `link`). Others offer a pseudo-version `system` that simply falls through to PATH (rbenv, pyenv, phpenv, phpvm). Almost none of them validate the linked folder beyond its name. Shims are built from `versions/*/bin/*`, so the only implicit contract is "has a `bin/` with executables".

### Cited Findings
- mise: `mise link [-f] <TOOL@VERSION> <PATH>` will "Symlink a tool version into mise". PATH is the "Directory of the existing installation". Examples are `mise link node@24.11.0 ~/.nodes/24.11.0` and `mise link node@brew "$(brew --prefix node)"`, then `mise use node@brew`. The version must be concrete (`latest`, aliases and channels are rejected). The docs describe no validation of the path. — [mise docs: link](https://mise.jdx.dev/cli/link.html)
- rbenv: you can compile Ruby "as a subdirectory of `~/.rbenv/versions`", and an entry "can also be a symlink to a Ruby version installed elsewhere". `system` uses the Ruby found on `$PATH`. — [rbenv README](https://github.com/rbenv/rbenv/blob/master/README.md)
- pyenv: version names "are simply directories under" `$(pyenv root)/versions`. `system` is whatever is on PATH after the shims, and pyenv does "not attempt to inspect or distinguish" system Pythons. — [pyenv README](https://github.com/pyenv/pyenv/blob/master/README.md)
- phpenv: each version is "a directory resulting from a PHP installation" under `~/.phpenv/versions/`. Shims are generated from `versions/*/bin/*` by `phpenv rehash`, and `system` means the PHP on `$PATH`. The README documents no Homebrew-linking command and no validation. — [phpenv README](https://github.com/phpenv/phpenv)
- phpvm (Thavarshan): it does not build PHP. It drives Homebrew, apt, dnf, yum and pacman, and switches "through Homebrew links or Linux alternatives". `phpvm system` and a `system` entry in `phpvm list` adopt the OS or Homebrew PHP. Session mode changes only the CLI, not `phpize`/`php-config`. — [Thavarshan/phpvm](https://github.com/Thavarshan/phpvm)
- hjbdev/pvm (Windows): it supports x64 only, has `pvm install`/`list`/`use`, and keeps its binary in `%UserProfile%\.pvm\bin`. The README does not document a way to add existing folders or detect TS/arch. — [hjbdev/pvm](https://github.com/hjbdev/pvm)

### Inferences
- PVM's "plug in" command could follow `mise link <ver> <path>` (a symlink or junction into PVM's versions dir) but should go further and validate the folder, which none of these tools document. A minimal probe:
  1. Find the binary: `bin/php` (Unix) or `php.exe` (Windows).
  2. Run `php -r` to print `PHP_VERSION`, `PHP_ZTS`, `PHP_INT_SIZE`/`php_uname('m')`, `PHP_EXTENSION_DIR`, `php_ini_loaded_file()` and `php_ini_scanned_files()`.
  3. On Unix, check that sibling `phpize`/`php-config` exist and that `php-config --prefix` equals the folder. If not, it is a moved build or a split package, and `pecl install` may break.
  4. On Windows, read TS/NTS from `php8ts.dll` versus `php8.dll`, or from `php -i` "Thread Safety".
- Debian/ondrej installs are not folder-shaped (`/usr/bin/php8.3`). Adopting them needs a "binary-path" form (point at `php8.3`, then derive `phpize8.3`/`php-config8.3` and use `pecl -d php_suffix=8.3`) rather than a folder.

### Gaps
- I did not check phpbrew, asdf's `path:` versions, nvm or Volta. As far as I know, asdf supports `system` and `path:<dir>` in `.tool-versions` **[unverified]**.

## 4. What makes a folder self-contained, and can a source-built Unix PHP be moved?

### Takeaway
A PHP build is fully self-contained only on Windows. On Linux/macOS, `--prefix`, `--with-config-file-path`, `--with-config-file-scan-dir` and the extension dir are compiled into the binary and written as absolute paths into `phpize` and `php-config`. Moving a source-built PHP therefore breaks `pecl`/`phpize` and default ini/ext lookup unless they are overridden (`-c`, `PHPRC`, `PHP_INI_SCAN_DIR`, `extension_dir`) or the scripts are patched.

### Cited Findings
- phpize gets its paths from `php-config --prefix`, substituted at build time. For example, Debian's `phpize.m4` sets phpdir to `$prefix/lib/php/<API>/build`. — [sources.debian.org phpize.m4](https://sources.debian.org/src/php8.4/8.4.16-1/scripts/phpize.m4) (search summary; the direct fetch of `phpize.in` returned 404)
- A PHP bug report notes that the install target hardcodes directories, "making it very difficult to install multiple versions of php or relocate php". — [bugs.php.net (search result)](https://bugs.php.net/bug.php?id=43857) (I could not confirm which exact bug ID carries that quote)
- For extension builds, the php.net manual points to `--with-php-config` to pick the PHP installation. — [php.net phpize manual](https://php.net/manual/de/install.pecl.phpize.php)
- Nix had to pass `--includedir` so that `php-config` reported correct header paths. This shows `php-config` echoes the configure-time paths. — [nixpkgs commit](https://git.uninsane.org/colin/nixpkgs/commit/b330329768cc753b6bd8f0e6e3f398382566f7c8)
- Homebrew works around this by rewriting `php-config`'s ext dir and running pear `config-set` after install. — [php@8.3.rb](https://raw.githubusercontent.com/shivammathur/homebrew-php/main/Formula/php@8.3.rb)

### Inferences
- For PVM on Linux/macOS, the safest per-version layout is to build with `--prefix=<PVM_HOME>/versions/X.Y.Z`, `--with-config-file-path=<prefix>/etc` and `--with-config-file-scan-dir=<prefix>/etc/conf.d`, and to keep the default `extension_dir` inside the prefix. Then run that version's `bin/pecl config-set php_ini <prefix>/etc/php.ini` (and `ext_dir`, `bin_dir`) so `bin/pecl install` stays local, Homebrew-style.
- Treat Unix builds as non-relocatable. If PVM_HOME moves, rebuild, or patch `php-config`/`phpize`/`pear.conf`. A plugged-in folder whose `php-config --prefix` does not match its real location should be flagged as "runs, but pecl/phpize may target the wrong place".
- Extensions are ABI-bound to version, ZTS and debug build (the ZEND_MODULE_API directory name, such as `20230831`, encodes the API). So the extension dir must be per version, not shared.

### Gaps
- No primary source fetched for the exact php.ini search order (php.net "The configuration file" page), or for rpath and libphp linkage in moved builds. These should be checked before the design relies on them.
