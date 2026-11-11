# Most-used PHP extensions and how to get them on Linux, macOS and Windows

Research date: 2026-11-10. Most of the data was pulled live with `curl`/`gh` from primary endpoints on that date (download counts, directory listings, Launchpad API, Packagist API). "Observed" means seen directly in that output. "Unverified" means it is from general knowledge or a secondary summary and was not checked against a primary page in this pass.

Prior work (not redone here): `reports/PHP source and extension strategy for Linux and macOS.md` covers static-php `bulk` contents, PIE mechanics, and the fact that xdebug can't be built static.

## What usage evidence exists, and what does the ranking look like?

### Takeaway
The best quantitative signal is the PECL all-time download table. Its top 10 is redis, imagick, xdebug, apcu, pcov, yaml, memcached, mongodb, amqp and igbinary. Packagist `type: php-ext` (PIE) downloads give almost the same order and are a newer, smaller signal. Framework requirement pages only name **bundled** extensions (intl, gd, zip, bcmath, soap, sodium, pdo_*). So bundled extensions have to be ranked by framework demand, not by download counts.

### Cited Findings

**PECL all-time downloads** (observed; the page said "Last updated: Wed Jun 17 13:08:36 2026 UTC", total 780,732,738) — [pecl.php.net/package-stats.php](https://pecl.php.net/package-stats.php):

| # | Package | Downloads |
|---|---|---|
| 1 | redis | 95,342,659 |
| 2 | imagick | 93,655,669 |
| 3 | Xdebug | 85,802,853 |
| 4 | APCu | 43,822,826 |
| 5 | pcov | 32,075,420 |
| 6 | yaml | 30,664,201 |
| 7 | memcached | 30,080,592 |
| 8 | mongodb | 28,114,805 |
| 9 | htscanner (legacy) | 26,654,667 |
| 10 | amqp | 19,080,750 |
| 11 | timezonedb | 18,982,809 |
| 12 | mcrypt (legacy) | 16,234,270 |
| 13 | igbinary | 14,515,634 |
| 14 | memcache | 13,083,675 |
| 15 | zip | 13,052,511 |
| 16 | ssh2 | 11,859,321 |
| 17 | sqlsrv | 10,204,399 |
| 18 | pdo_sqlsrv | 9,688,420 |
| 19 | swoole | 9,558,794 |
| 20 | rdkafka | 9,396,508 |
| 21 | smbclient | 7,952,916 |
| 23 | mailparse | 6,792,427 |
| 24 | gnupg | 6,715,864 |
| 25 | oci8 | 6,468,946 |
| 27 | msgpack | 5,365,178 |
| 28 | pecl_http | 4,698,235 |
| 29 | gRPC | 4,338,793 |
| 30 | protobuf | 4,303,412 |
| 31 | event | 4,292,702 |
| 33 | ast | 3,540,440 |
| 34 | opentelemetry | 3,535,787 |
| 36 | oauth | 3,375,803 |
| 37 | excimer | 3,175,352 |
| 40 | xhprof | 2,875,173 |
| 42 | uuid | 2,240,214 |
| 47 | ds | 1,884,035 |

(Ranks 22, 26, 32, 35 and so on are dead or legacy packages such as `mongo`, `APC`, `Mosquitto` and `libsodium`. They were omitted.)

**Packagist PIE packages (`type: php-ext`), all-time downloads** (observed, top 300 results by search API) — [packagist.org/search.json?type=php-ext](https://packagist.org/search.json?type=php-ext&per_page=100):
- phpredis/phpredis 557,532; phalcon/cphalcon 256,588; pdezwart/php-amqp 255,014 plus php-amqp/php-amqp 121,478; pecl/pcov 230,306; imagick/imagick 224,021; apcu/apcu 197,289; open-telemetry/ext-opentelemetry 156,481; mongodb/mongodb-extension 105,213; php-memcached/php-memcached 99,154; rdkafka/rdkafka 60,265; pecl/yaml 48,259; igbinary/igbinary 41,598; swoole/swoole 34,944; php-ds/ext-ds 31,773; pecl/mailparse 25,892; pecl/zip 25,482; msgpack/msgpack-php 25,296; pecl/uuid 24,981; valkey-io/valkey-glide-php 24,274; microsoft/pdo_sqlsrv 19,221; nikic/php-ast 18,892; microsoft/sqlsrv 18,109; wikimedia/excimer 13,793.
- xdebug/xdebug: 508,282 total, 119,411 monthly — [packagist stats.json](https://packagist.org/packages/xdebug/xdebug/stats.json). It did not show up in the search API sample, so search results are not a complete ranking.
- The `asgrim/example-pie-extension` package (593,334) is PIE's test fixture and should be ignored — [same search](https://packagist.org/search.json?type=php-ext&per_page=100).

**Packagist `ext-*` requirement counts:** Packagist does not expose a "dependents" count for platform packages (`ext-*`). **Gap.**

**Framework requirement pages (all bundled extensions):**
- Laravel 12 requires PHP >= 8.2 plus ctype, curl, dom, fileinfo, filter, hash, mbstring, openssl, pcre, pdo, session, tokenizer and xml — [laravel/docs deployment.md](https://github.com/laravel/docs/blob/12.x/deployment.md#server-requirements).
- Symfony 7.4 requires PHP 8.2+ with ctype, iconv, pcre, session, simplexml and tokenizer — [symfony-docs setup.rst](https://github.com/symfony/symfony-docs/blob/7.4/setup.rst).
- WordPress Site Health checks bcmath, curl, dom, exif, fileinfo, hash, **imagick**, json, mbstring, mysqli, libsodium, openssl, pcre, xml, zip, filter, gd, iconv and intl. Only hash and json are flagged `required => true` — [class-wp-site-health.php (trunk)](https://github.com/WordPress/wordpress-develop/blob/trunk/src/wp-admin/includes/class-wp-site-health.php). This makes imagick the only PECL extension that WordPress recommends.
- Adobe Commerce/Magento 2.4.8 requires bcmath, ctype, curl, dom, fileinfo, filter, ftp, gd, hash, iconv, intl, json, libxml, mbstring, openssl, pcre, pdo_mysql, reflection, simplexml, **soap**, **sockets**, **sodium**, spl, tokenizer, xmlwriter, **xsl**, zip and zlib. OPcache is recommended, and pcntl is optional — [Adobe Experience League system requirements](https://experienceleague.adobe.com/en/docs/commerce-operations/installation-guide/system-requirements).
- Drupal 10/11 requires PDO, a DB driver (sqlite/mysql/pgsql), **GD**, JSON and XML/DOM. OpenSSL, cURL and mbstring are conditional — [drupal.org PHP requirements](https://www.drupal.org/docs/getting-started/system-requirements/php-requirements).

**JetBrains survey:** A search-result summary of JetBrains "State of PHP 2025" (1,720 respondents) reported 59% using var_dump-style debugging and 39% using a debugger such as Xdebug, up from 33% in 2024. The primary page returned HTTP 403 to the fetcher, so this is **unverified** — [JetBrains blog](https://blog.jetbrains.com/phpstorm/2025/10/state-of-php-2025/). The Laravel News recap only confirms the 1,720 respondents and "89% of respondents are using PHP 8.x" — [laravel-news](https://laravel-news.com/jetbrains-state-of-php-2025).

**docker-php-extension-installer:** supports 164 extension rows, including grpc, xdebug, pcov, swoole, imagick, sqlsrv and pdo_sqlsrv for 5.5/7.x through 8.5 (observed). Only some extensions list 8.6 so far: opentelemetry and uuid do, xdebug, pcov and grpc don't — [data/supported-extensions](https://github.com/mlocati/docker-php-extension-installer/blob/master/data/supported-extensions). It has no public usage counts per extension. **Gap.**

### Proposed ranked list (~30)
Ranking method (inference): PECL downloads for PECL-only extensions, merged with framework demand for bundled ones. Legacy or dead packages (htscanner, mcrypt, APC, mongo) are dropped.

| Rank | Extension | Kind | Main evidence |
|---|---|---|---|
| 1 | opcache | bundled (zend_extension; always built in from 8.5, see below) | Magento recommends it; on by default in distros |
| 2 | intl | bundled (`--enable-intl`, needs ICU) | Magento required; WP recommended |
| 3 | gd | bundled (`--enable-gd`) | Drupal and Magento required; WP recommended |
| 4 | zip | bundled (`--with-zip`, libzip); also PECL | Magento required; WP; PECL 13.0M |
| 5 | redis (phpredis) | PECL | PECL #1, 95.3M; PIE 557k |
| 6 | imagick | PECL, needs ImageMagick | PECL #2, 93.7M; WP Site Health |
| 7 | xdebug | PECL zend_extension | PECL #3, 85.8M; JetBrains ~39% (unverified) |
| 8 | bcmath | bundled | Magento required; WP |
| 9 | sodium | bundled (`--with-sodium`, libsodium) | Magento required; WP |
| 10 | soap | bundled | Magento required |
| 11 | pdo_pgsql / pgsql | bundled (libpq) | Drupal DB option |
| 12 | apcu | PECL | PECL 43.8M; PIE 197k |
| 13 | pcov | PECL | PECL 32.1M; PIE 230k |
| 14 | yaml | PECL, needs libyaml | PECL 30.7M |
| 15 | memcached | PECL, needs libmemcached | PECL 30.1M |
| 16 | mongodb | PECL (bundles libmongoc) | PECL 28.1M |
| 17 | amqp | PECL, needs librabbitmq | PECL 19.1M; PIE 376k (two names) |
| 18 | igbinary | PECL | PECL 14.5M |
| 19 | ldap | bundled (OpenLDAP) | no download signal |
| 20 | ssh2 | PECL, needs libssh2 | PECL 11.9M |
| 21 | sqlsrv / pdo_sqlsrv | PECL (Microsoft), needs ODBC + msodbcsql | PECL 10.2M + 9.7M |
| 22 | swoole | PECL | PECL 9.6M |
| 23 | rdkafka | PECL, needs librdkafka | PECL 9.4M |
| 24 | timezonedb | PECL | PECL 19.0M (pure data, low effort) |
| 25 | memcache | PECL | PECL 13.1M |
| 26 | mailparse | PECL | PECL 6.8M |
| 27 | msgpack | PECL | PECL 5.4M |
| 28 | grpc | PECL (huge C++ build) | PECL 4.3M |
| 29 | protobuf | PECL | PECL 4.3M |
| 30 | opentelemetry | PECL | PECL 3.5M; PIE 156k |
| 31 | event | PECL, needs libevent | PECL 4.3M |
| 32 | excimer / xhprof | PECL | PECL 3.2M / 2.9M |
| 33 | uuid | PECL, needs libuuid | PECL 2.2M |
| 34 | ast, ds | PECL | PECL 3.5M / 1.9M |

### Inferences
- PECL counts understate distro-packaged usage, since apt, rpm and brew installs don't hit pecl.php.net. They also overstate CI-heavy extensions (pcov, xdebug), which are re-downloaded on every Docker and CI build.
- For a version manager, the "must work on day one" set is the bundled framework extensions plus redis, imagick, xdebug, pcov and apcu.

### Gaps
- No Packagist `ext-*` dependents count. No setup-php or docker-php-extension-installer telemetry.
- The JetBrains Xdebug figure is unverified (403).
- Ranks of bundled extensions are judgement calls, not measured.

## Is each extension bundled or PECL-only, what system libraries does it need, and can it be static?

### Takeaway
intl, gd, zip, bcmath, soap, sodium, ldap, pgsql and opcache are in php-src. Everything else in the list is PECL or third-party. The heavy-dependency cases are imagick (ImageMagick), sqlsrv (Microsoft ODBC driver), rdkafka, memcached, grpc (a large bundled C++ core, slow to compile) and, for gd, AVIF support. xdebug cannot be built static.

### Cited Findings
- From PHP 8.5, ondrej publishes `php8.4-opcache` but no `php8.5-opcache` package (Launchpad `total_size` 0, observed). That is consistent with OPcache being compiled into PHP 8.5 rather than shipped separately (the RFC was not fetched, **unverified**) — [Launchpad API php8.5-opcache](https://api.launchpad.net/1.0/~ondrej/+archive/ubuntu/php?ws.op=getPublishedBinaries&binary_name=php8.5-opcache&exact_match=true&status=Published).
- Remi still ships `php84-php-opcache` (observed) — [remi safe EL9 listing](https://rpms.remirepo.net/enterprise/9/safe/x86_64/).
- Building gd with AVIF needs libaom/libdav1d/libyuv/libavif compiled on older distros, which "is time-consuming" — [docker-php-extension-installer README](https://github.com/mlocati/docker-php-extension-installer/blob/master/README.md).
- docker-php-extension-installer "compiles or downloads" libraries "when they aren't provided by the system" — [same README](https://github.com/mlocati/docker-php-extension-installer/blob/master/README.md).
- Some extensions need ZTS: parallel and pthreads require thread-safe builds — [data/special-requirements](https://github.com/mlocati/docker-php-extension-installer/blob/master/data/special-requirements).
- xdebug is `build-static: false` in static-php-cli. The static `bulk` set lacks grpc, mongodb, sqlsrv/pdo_sqlsrv, memcached, ldap, yaml and amqp — see prior report, citing [ext-xdebug.yml](https://github.com/crazywhalecc/static-php-cli/blob/v3/config/pkg/ext/ext-xdebug.yml) and [bulk README.txt](https://dl.static-php.dev/v3/php-bin/bulk/README.txt).
- System library mapping (**unverified in this pass**, from each extension's install docs and general knowledge): imagick → ImageMagick MagickWand; memcached → libmemcached (+ zlib, optional igbinary/msgpack); rdkafka → librdkafka; yaml → libyaml; ssh2 → libssh2; amqp → librabbitmq-c; event → libevent; uuid → libuuid; sqlsrv/pdo_sqlsrv → unixODBC + Microsoft msodbcsql (Linux/macOS); mongodb, grpc and protobuf vendor their C/C++ dependencies; intl → ICU; gd → libpng/libjpeg/freetype/libwebp(/libavif); zip → libzip; ldap → OpenLDAP; pgsql → libpq; sodium → libsodium.

### Inferences
- Pure-C, no-dependency PECL extensions are easy to build from source everywhere: apcu, pcov, xdebug, igbinary, msgpack, timezonedb, mailparse, ds, ast, excimer, xhprof, opentelemetry. With PIE they mostly take seconds to a minute.

### Gaps
- No measured compile times. The claim that grpc takes many minutes is widely reported but was not measured here.
- pcov's static-php status was not re-checked (the prior report grouped it with xdebug).

## Which channels provide each extension, per platform?

### Takeaway
On PHP 8.4 and 8.5 almost every extension in the list is available from every major channel: ondrej apt, Remi RPM, shivammathur Homebrew, and PECL Windows DLLs. The remaining holes are uuid, excimer and pre-8.3 sqlsrv on Windows, swoole on Homebrew 8.6+, and older-PHP cut-offs on Windows (mongodb ≥ 8.1, swoole/protobuf/ds ≥ 8.2). PIE covers most PECL extensions, but **official** grpc, protobuf, ssh2, xhprof and excimer are missing from PIE's in-tree list. The live Packagist index has more than the in-tree doc.

### Cited Findings

**Availability matrix** (observed 2026-11-10; ✅ = present, ❌ = absent, — = not checked):

| Extension | ondrej apt `php8.4-`/`php8.5-` | Remi EL9 `php84`/`php85` | Homebrew `shivammathur/extensions/<ext>@X.Y` | PECL Windows DLL (latest release) | PIE (in-tree list) |
|---|---|---|---|---|---|
| redis | ✅/✅ | ✅/✅ (`pecl-redis`) | formula named `phpredis` (versions not listed) | 6.3.0: 8.0–8.5 | ✅ phpredis/phpredis |
| imagick | ✅/✅ | ✅/✅ | 5.6–8.7 | 3.8.1: 8.0–8.5 | ✅ |
| xdebug | ✅/✅ | ✅/✅ (`pecl-xdebug3`) | 5.6–8.7 | 3.5.3: 8.0–8.5 | ✅ |
| apcu | ✅/✅ | ✅/✅ | 5.6–8.7 | 5.1.28: 8.0–8.5 | ✅ |
| pcov | ✅/✅ | ✅/✅ | 7.1–8.7 | 1.0.12: 8.0–8.5 | ✅ |
| yaml | ✅/✅ | ✅/✅ | 5.6–8.7 | 2.3.0: 8.0–8.5 | doc: WIP; Packagist has pecl/yaml |
| memcached | ✅/✅ | ✅/✅ | 5.6–8.7 | 3.4.0: 8.0–8.5 | ✅ |
| mongodb | ✅/✅ | ✅ (`pecl-mongodb2`)/✅ | 5.6–8.7 | 2.5.7: 8.1–8.5 | ✅ |
| amqp | ✅/✅ | ✅/✅ | 5.6–8.7 | 2.2.0: 8.0–8.5 | ✅ |
| igbinary | ✅/✅ | ✅/✅ | 5.6–8.7 | 3.2.17RC1: 8.0–8.5 | doc: not started; Packagist has igbinary/igbinary |
| zip | ✅/✅ (bundled pkg) | ✅/✅ | none (built into brew `php`) | 1.22.8: 8.0–8.5 | ✅ pecl/zip |
| ssh2 | ✅/✅ | ✅/✅ | 5.6–8.7 | 1.5.0: 8.0–8.5 | ❌ not started |
| sqlsrv / pdo_sqlsrv | ✅ but only 2 builds/✅ (2) | ✅ (`php84-php-sqlsrv`)/✅ | 7.0–8.7 | 5.13.3: **8.3–8.5 only** | ✅ microsoft/* |
| swoole | ✅ (6 builds)/✅ | ✅/✅ | **5.6–8.5 only** | 6.3.0RC1: 8.2–8.5 | ✅ |
| rdkafka | ✅/✅ | ✅/✅ | 5.6–8.7 | 7.0.0alpha1: 8.1–8.5 | ✅ |
| mailparse | ✅/✅ | ✅/✅ | 5.6–8.7 | 3.2.0: 8.0–8.5 | ✅ |
| msgpack | ✅/✅ | ✅/✅ | 5.6–8.7 | 3.0.1: 8.0–8.5 | doc: not started; Packagist has msgpack/msgpack-php |
| grpc | ✅/✅ | ✅/✅ | 5.6–8.7 | 1.85.0: 8.0–8.5 | ❌ official; only bsn4/grpc (Rust) |
| protobuf | ✅/✅ | ✅/✅ | 5.6–8.7 | 5.36.2: 8.2–8.5 | ❌ not started |
| event | — | ✅/✅ | 5.6–8.7 | 3.2.0: 8.0–8.5 | ✅ osmanov/pecl-event |
| ast | ✅/✅ | ✅ (`php84-php-ast`)/✅ | 7.0–8.7 | 1.1.4: 8.0–8.5 | ✅ |
| opentelemetry | ✅/✅ | ✅/✅ | 8.0–8.7 | 1.5.0: 8.1–8.5 | ✅ |
| excimer | ✅/✅ | ✅/✅ | 7.1–8.7 | **no Windows dir** | doc: not started; Packagist has wikimedia/excimer |
| xhprof | ✅/✅ | ✅/✅ | 7.0–8.7 | 2.3.10: 8.0–8.5 | ❌ not started |
| uuid | ✅/✅ | ✅/✅ | 5.6–8.7 | **no Windows dir** | ✅ pecl/uuid |
| ds | ✅/✅ | ✅/✅ | 7.0–8.7 | 2.0.0: 8.2–8.5 | ✅ |
| memcache | ✅/✅ | ✅/✅ | 5.6–8.7 | 8.2: 8.0–8.5 | doc: WIP |
| timezonedb | — | — | — | 2026.6: 8.0–8.5 | ✅ |
| intl, gd, ldap, soap, bcmath, pgsql | ✅/✅ | ✅ (`php84-php-<ext>`) | none (in brew core `php`, unverified) | ship in the php.net Windows zip (unverified) | n/a (bundled) |
| imap | ✅/✅ | — | 5.6–8.7 (unbundled from php-src in 8.4, unverified) | — | — |

Sources for the matrix:
- ondrej: Launchpad `getPublishedBinaries` with `binary_name=php8.X-<ext>&exact_match=true&status=Published`, e.g. [php8.5-grpc](https://api.launchpad.net/1.0/~ondrej/+archive/ubuntu/php?ws.op=getPublishedBinaries&binary_name=php8.5-grpc&exact_match=true&status=Published). Most packages returned `total_size` 8 (builds across series and architectures). php8.4/8.5-sqlsrv returned 2 and swoole returned 6, which suggests fewer series or architectures (inference).
- Remi: filenames in [rpms.remirepo.net/enterprise/9/safe/x86_64/](https://rpms.remirepo.net/enterprise/9/safe/x86_64/) (`php84-php-pecl-<ext>-…rpm`).
- Homebrew: [shivammathur/homebrew-extensions Formula dir](https://github.com/shivammathur/homebrew-extensions/tree/main/Formula) (825 formula files).
- Windows: `https://downloads.php.net/~windows/pecl/releases/<ext>/<latest>/`, e.g. [grpc/1.85.0](https://downloads.php.net/~windows/pecl/releases/grpc/1.85.0/) and [sqlsrv/5.13.3](https://downloads.php.net/~windows/pecl/releases/sqlsrv/5.13.3/). NTS x64 zips exist for 8.0–8.3 (vs16) and 8.4–8.5 (vs17). **No 8.6 DLLs** were seen for any extension. `excimer/` and `uuid/` returned no directory.
- PIE: [php/pie docs/supported-extensions.md (1.6.x)](https://github.com/php/pie/blob/1.6.x/docs/supported-extensions.md). The doc says the full list lives at [packagist.org/extensions](https://packagist.org/extensions). The doc lists yaml and memcache as "⏰ PR", and igbinary, msgpack, excimer, protobuf, ssh2 and xhprof under "Not started / Unknown". **Conflict:** Packagist already has `pecl/yaml` (48k), `igbinary/igbinary` (42k), `msgpack/msgpack-php` (25k) and `wikimedia/excimer` (14k) as `php-ext` packages ([search](https://packagist.org/search.json?type=php-ext&per_page=100)), so the in-tree doc is stale.
- **PECL Windows DLLs still exist for PHP 8.3, 8.4 and 8.5** (answers the key question). Latest releases were built as recently as 2026 (timezonedb 2026.6, protobuf 5.36.2) — [releases index](https://downloads.php.net/~windows/pecl/releases/).

### Inferences
- PHP 8.6 is the coverage edge as of Nov 2026. Homebrew already has `@8.6`/`@8.7` formulas for most extensions, docker-php-extension-installer lists 8.6 for only a few, and PECL Windows has none yet. A version manager should expect extension gaps on 8.6 for its first months.
- Windows is now fine for most extensions. The real Windows holes are uuid (Linux-only libuuid), excimer, and sqlsrv on PHP < 8.3 from the latest release (older sqlsrv releases may cover older PHPs; not checked).

### Gaps
- ondrej php8.6 packages, Remi php86, and Debian sury (packages.sury.org) were not checked.
- Homebrew phpredis versions and bottle architectures per formula were not enumerated.
- static-php-cli's `bulk` list was not re-fetched (see prior report).
- Whether extension GitHub releases ship their own Windows DLLs (e.g. swoole, opentelemetry) was not checked.

## Which extensions are the hard cases?

### Takeaway
grpc (long C++ compile, official version not in PIE), sqlsrv/pdo_sqlsrv (Microsoft ODBC driver at runtime, Windows DLLs only for 8.3+ in the latest release), imagick (ImageMagick dependency on Linux/macOS), swoole (no Homebrew 8.6+, Windows only from 8.2), uuid and excimer (no Windows DLLs), and xdebug (can't be static, and it is a zend_extension).

### Cited Findings
- Official grpc is absent from PIE; only `bsn4/grpc`, a "drop-in Rust replacement for ext-grpc", is listed — [PIE supported-extensions](https://github.com/php/pie/blob/1.6.x/docs/supported-extensions.md).
- grpc is still easy as a prebuilt: ondrej `php8.5-grpc`, Remi `php85-php-pecl-grpc`, brew `grpc@8.7`, and Windows `grpc/1.85.0` for 8.0–8.5 (observed, sources in the matrix above).
- sqlsrv 5.13.3 Windows DLLs exist only for 8.3, 8.4 and 8.5 — [listing](https://downloads.php.net/~windows/pecl/releases/sqlsrv/5.13.3/).
- swoole Homebrew formulas stop at `@8.5` while most others reach `@8.7` — [Formula dir](https://github.com/shivammathur/homebrew-extensions/tree/main/Formula).
- No `uuid/` or `excimer/` directory under PECL Windows releases (observed) — [releases index](https://downloads.php.net/~windows/pecl/releases/).
- xdebug: `build-static: false` — [ext-xdebug.yml](https://github.com/crazywhalecc/static-php-cli/blob/v3/config/pkg/ext/ext-xdebug.yml).

### Inferences
- If PVM backs `pvm ext install` with prebuilt channels (apt, brew, PECL DLL), grpc stops being a hard case. It is only hard for from-source or PIE builds.
- The truly hard ones for every channel are the runtime-dependency extensions. sqlsrv needs the Microsoft ODBC driver installed system-wide, and imagick needs a matching ImageMagick. PVM can install the extension, but not those system pieces, without sudo or brew.

### Gaps
- No compile-time measurements for grpc, swoole or imagick.
- I did not check whether the PECL Windows imagick DLL zip bundles the ImageMagick DLLs (believed yes, **unverified**).
