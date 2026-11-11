# Raw notes: static-php v3 prebuilt archive inspection (2026-11-10)

All downloads with `curl -A "pvm-research/0.1"` into fresh, empty scratchpad dirs. Binaries were never executed. Downloads often broke mid-stream (`schannel: server closed abruptly`); `curl -C -` resume loops finished them.

## Archives tested

| Set | File | Archive size | Sidecar match | Contents |
|---|---|---|---|---|
| gnu-bulk | php-8.4.27-cli-linux-x86_64.tar.gz | 28.5M | yes (6572c344...fa72) | `php` only, 103,276,616 bytes, owner runner/runner, mtime 2026-11-10 11:33 |
| bulk (musl) | php-8.4.27-cli-linux-x86_64.tar.gz | 30.8M | yes (d856b480...b234) | `php` only, 33,152,160 bytes, mtime 2026-11-10 10:35 |
| bulk (macOS) | php-8.4.27-cli-macos-aarch64.tar.gz | 35.3M | yes (a687acb2...3c58) | `php` only, 98,499,472 bytes, owner runner/staff, mtime 2026-11-10 13:21 |

URLs: `https://dl.static-php.dev/v3/php-bin/<set>/<file>` and `<file>.sha256`.

First end-to-end sidecar match recorded (the earlier report said this was not verified). Three of three matched.

No archive has `phpize`, `php-config`, `include/php/`, `php.ini`, or an `ext/`/`modules/` dir.

## gnu-bulk ELF (readelf, Strawberry Perl binutils)

- `ELF 64-bit LSB pie executable, dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2`, stripped.
- NEEDED: libm.so.6, libc.so.6, ld-linux-x86-64.so.2, libresolv.so.2, libpthread.so.0, libdl.so.2, librt.so.1, libutil.so.1. FLAGS BIND_NOW, PIE.
- `.dynsym` holds about 43,150 entries. It exports `zend_parse_parameters`, `zend_register_functions`, `php_info_print_table_start`, `zend_extensions`, `ps_globals`, `php_session_register_module`. It imports `dlopen@GLIBC_2.2.5`.
- It also exports the bundled third-party libs: `SSL_new` (OpenSSL), `curl_easy_init`, `xmlReadMemory`, `sqlite3_open`, ICU (`*_77`), ImageMagick, libaom, krb5, ldap client (`ldap_build_bind_req`), gmp.
- Strings: `API20240924,NTS`, `/lib/php/extensions/no-debug-non-zts-20240924` (empty prefix), `/usr/local/etc/php`, `/usr/local/etc/php/conf.d`.

## musl bulk ELF

- `file`: `ELF 64-bit LSB shared object, statically linked, no section header`. `readelf -l`: no INTERP, and no `.dynsym` entries.
- Strings: `$Info: This file is packed with the UPX executable packer` and `UPX 5.30`. This matches the README's `--with-upx-pack`.
- A packed, fully static binary has no dynamic loader, so `dlopen` of a `.so` is impossible.

## macOS bulk Mach-O (my own parser, scripts/macho.py in scratchpad)

- `Mach-O 64-bit arm64 executable`, flags NOUNDEFS|DYLDLINK|TWOLEVEL|PIE.
- LC_LOAD_DYLIB: /usr/lib/libc++.1.dylib, /usr/lib/libSystem.B.dylib, /usr/lib/libresolv.9.dylib, plus the CoreFoundation, Kerberos, CoreServices and SystemConfiguration frameworks.
- LC_DYLD_EXPORTS_TRIE is 688,176 bytes. LC_DYSYMTAB has 26,770 externally defined symbols and 834 undefined ones. The strings include `_zend_parse_parameters`, `_dlopen` and `_zend_register_functions`.
- LC_CODE_SIGNATURE is present (probably ad-hoc; not checked).
- Same ABI string `API20240924,NTS`, the same extension_dir default and the same ini paths as Linux.

## Inference

- gnu-bulk and macOS: technically able to `dlopen` an NTS `.so` built against PHP 8.4 (API 20240924) headers, with symbols resolved from the executable. **Not run-tested.** No Linux or macOS host was available.
- Risk: gnu-bulk exports its own OpenSSL, libxml2, ICU and so on. A `.so` that pulls in the system's libssl or libxml2 could have its calls bound to PHP's bundled copies (ELF symbol interposition), which can break if the versions differ.
- extension_dir is `/lib/php/extensions/...` and php.ini is looked up in `/usr/local/etc/php`. PVM must set `PHPRC`/`-c`/`PHP_INI_SCAN_DIR` and an absolute `extension_dir`.

## Set contents (README.txt and build-manifest.json, 2026-11-10)

- bulk = gnu-bulk = 56 named: apcu, bcmath, bz2, calendar, ctype, curl, dba, dom, event, exif, fileinfo, filter, ftp, gd, gmp, iconv, imagick, imap, intl, mbregex, mbstring, mysqli, mysqlnd, opcache, openssl, opentelemetry, pcntl, pdo, pdo_mysql, pgsql, phar, posix, protobuf, readline, redis, session, shmop, simplexml, soap, sockets, sodium, sqlite3, swoole, swoole-hook-mysql, swoole-hook-pgsql, swoole-hook-sqlite, sysvmsg, sysvsem, sysvshm, tokenizer, xml, xmlreader, xmlwriter, xsl, zip, zlib. `--with-suggests` also pulls in libxml, igbinary, msgpack and swoole-hook-odbc (manifest).
- **No `pdo_sqlite`, `pdo_pgsql`.** spc docs: swoole-hook-sqlite "conflicts with the `pdo_sqlite` extension" and provides coroutine pdo_sqlite instead. Whether `new PDO('sqlite:...')` works outside coroutines in the bulk binary is **unverified**.
- common (37) includes pdo_sqlite and pdo_pgsql.
- Missing from every set: xdebug, pcov, grpc, mongodb, sqlsrv/pdo_sqlsrv, memcached, ldap (lib present only as a curl dep), gettext, tidy, yaml, amqp, xhprof.

## CI build time (static-php/hosted run 41790368886, 2026-11-04)

bulk jobs ran about 40–60 min on Linux x86_64/arm64, about 45 min on macos-15, and 80–100 min on macos-15-intel. gnu-bulk jobs ran about 37–46 min. These runs use `--dl-prefer-binary` prebuilt libs.
