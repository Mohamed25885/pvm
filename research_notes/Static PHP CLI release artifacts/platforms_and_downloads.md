# Static PHP CLI release artifacts: platforms and downloads

Observed 2026-11-10. Everything below comes from fetching dl.static-php.dev live (HTML listings plus their `?format=json` variant), the GitHub API for `crazywhalecc/static-php-cli` and `static-php/hosted`, and raw workflow and README files. "Historical" marks the legacy v2 tree, which no longer gets fresh builds.

## Where are prebuilt binaries hosted, and what are the URL and filename patterns?

### Takeaway
Prebuilt PHP binaries are hosted only on dl.static-php.dev. GitHub Releases of crazywhalecc/static-php-cli carry only the `spc` build tool, never PHP. The current tree is `https://dl.static-php.dev/v3/php-bin/<set>/php-<X.Y.Z>-<sapi>-<os>-<arch>.tar.gz` for Linux and macOS, and `https://dl.static-php.dev/v3/php-bin/<set>/php-<X.Y.Z>-<sapi>-win.zip` for Windows. Each archive has a `.sha256` sidecar file. The older `https://dl.static-php.dev/static-php-cli/...` tree is legacy: its newest uploads date from July 2026.

### Cited Findings
- The host root (`https://dl.static-php.dev/?format=json`) lists the directories `assets/`, `frankenphp/`, `packages/`, `static-php-cli/` (legacy v2) and `v3/`. `v3/` was last modified 2026-10-09 — [dl root JSON](https://dl.static-php.dev/?format=json)
- `v3/` contains `deps/`, `php-bin/` (last modified 2026-11-10 08:35:44), `spc-bin/` and `tools/` — [v3 JSON](https://dl.static-php.dev/v3/?format=json)
- `v3/php-bin/` holds six sets: `bulk/`, `common/`, `gnu-bulk/`, `minimal/`, `spc-max/` and `spc-min/`. The Windows sets sit directly under php-bin. In the legacy tree they sat under `windows/` — [v3/php-bin](https://dl.static-php.dev/v3/php-bin/)
- The v3 README on the repo's default branch (`v3`) links that exact table. Its "Direct Download" section lists:
  - common: 37 extensions, "about 13MB", Linux and macOS
  - bulk: 56 extensions, about 30MB, Linux and macOS
  - gnu-bulk: 56 extensions, Linux, "Using shared glibc"
  - minimal: 7 extensions, about 3MB, Linux and macOS
  - spc-min: 7 extensions, about 3MB, Windows
  - spc-max: 50 extensions, about 9MB, Windows
  - It also notes that macOS builds are larger because macOS does not support UPX compression.
  - Source: [README (v3 branch)](https://raw.githubusercontent.com/crazywhalecc/static-php-cli/v3/README.md)
- The repo's default branch is `v3`, last pushed 2026-11-10 — [GitHub API repos/crazywhalecc/static-php-cli](https://api.github.com/repos/crazywhalecc/static-php-cli)
- Filenames observed in the v3 tree:
  - `php-8.5.12-cli-linux-x86_64.tar.gz`
  - `php-8.5.12-micro-macos-aarch64.tar.gz`
  - `php-8.2.32-fpm-linux-aarch64.tar.gz`
  - `php-8.5.12-cli-win.zip`
  - `php-8.5.12-micro-win.zip`
  - `php-8.5.12-cli-win.zip.sha256`
  - Sources: [v3/php-bin/common](https://dl.static-php.dev/v3/php-bin/common/?format=json), [v3/php-bin/spc-min](https://dl.static-php.dev/v3/php-bin/spc-min/?format=json)
- How the Unix workflow packages archives:
  - It runs `tar -czf "dist/php-$PHPVER-cli-$OS-$ARCH.tar.gz" -C tmp_dist/ php`. Each tarball holds a single file: `php`, `micro.sfx` or `php-fpm`.
  - `OS` is `linux` or `macos`. `ARCH` is `x86_64` or `aarch64`.
  - Source: [static-php/hosted v3-php-bin-unix.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-unix.yml)
- How the Windows workflow packages archives:
  - It runs `Compress-Archive -Path "buildroot\bin\php.exe" -DestinationPath "dist\php-$PHPVER-cli-win.zip"`, and the same for `micro.sfx` into `php-$PHPVER-micro-win.zip`.
  - So each zip holds exactly one file, `php.exe` or `micro.sfx`. There is no php.ini, no DLLs and no ext folder.
  - Source: [static-php/hosted v3-php-bin-windows.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-windows.yml)
- Checksums:
  - Each archive gets a `<archive>.sha256` sidecar in `<hash>  <name>` format, so `sha256sum -c` can check it. The workflow comment explains this replaced a shared checksum file that parallel jobs overwrote.
  - Example content observed: `6c464e042c2909b59254c666aaa2c3b553361bfa81a1fffdc3c035212f77368f  php-8.5.12-cli-win.zip`
  - Sources: [v3-php-bin-windows.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-windows.yml), [sha256 file](https://dl.static-php.dev/v3/php-bin/spc-min/php-8.5.12-cli-win.zip.sha256)
- Sidecars exist only for the newest patch release of each minor version (8.2.35, 8.3.36, 8.4.27, 8.5.12). Older archives in the same directory have no `.sha256` file — [v3/php-bin/common JSON](https://dl.static-php.dev/v3/php-bin/common/?format=json)
- Legacy v2 tree (historical):
  - Paths: `https://dl.static-php.dev/static-php-cli/{common,bulk,minimal,gnu-bulk}/` and `.../static-php-cli/windows/{spc-max,spc-min}/`.
  - Filename pattern is the same, e.g. `php-8.0.30-cli-win.zip`. There are no sha256 sidecars.
  - The main-branch README still points there.
  - Sources: [legacy listing](https://dl.static-php.dev/static-php-cli/), [README (main branch)](https://raw.githubusercontent.com/crazywhalecc/static-php-cli/main/README.md)
- GitHub Releases (e.g. 2.8.5, 2026-04-18) carry only `spc-linux-aarch64.tar.gz`, `spc-linux-x86_64.tar.gz`, `spc-macos-aarch64.tar.gz`, `spc-macos-x86_64.tar.gz` and `spc-windows-x64.exe`. These are the builder tool, not PHP — [GitHub API releases](https://api.github.com/repos/crazywhalecc/static-php-cli/releases)
- Nightly `spc` tool binaries for v3 are at `https://dl.static-php.dev/v3/spc-bin/nightly/`, last updated 2026-11-09. Files include `spc-windows-x64.exe`, `spc-linux-x86_64` and `spc.phar` — [v3 spc-bin nightly](https://dl.static-php.dev/v3/spc-bin/nightly/?format=json)
- The workflows in the main repo (`build-unix.yml`, `build-windows-x86_64.yml`) are manual `workflow_dispatch` builds. They only `actions/upload-artifact` and do not publish to dl.static-php.dev — [build-unix.yml](https://github.com/crazywhalecc/static-php-cli/blob/main/.github/workflows/build-unix.yml), [build-windows-x86_64.yml](https://github.com/crazywhalecc/static-php-cli/blob/main/.github/workflows/build-windows-x86_64.yml)

### Inferences
- The `os-arch` suffix does not tell glibc and musl builds apart. Both are named `linux-x86_64`, and only the set directory (`gnu-bulk/` vs the others) shows which libc a build uses. A client has to key on (set, filename), not on filename alone.
- Windows filenames carry no architecture (`-win.zip`). That is safe today only because x86_64 is the only Windows arch published.
- Each zip holds a lone `php.exe`, so a Windows version manager has to supply its own php.ini. The archive gives it nothing to unpack beyond the binary.

### Gaps
- I did not download a binary archive to confirm its contents. The internal layout above is inferred from the packaging step in the workflow.
- I found no documented stability guarantee for the `v3/php-bin/` URL layout. The legacy tree shows paths have changed before (`windows/spc-max/` became `spc-max/`).

## Which platforms, arches, SAPIs, extension sets and PHP versions are published, and how often are they refreshed?

### Takeaway
The current v3 tree covers PHP 8.2, 8.3, 8.4 and 8.5 on these platforms:

| Platform | Sets | SAPIs | Linking |
|---|---|---|---|
| Linux x86_64 and aarch64 | common, bulk, minimal | cli, fpm, micro | musl, static |
| Linux x86_64 and aarch64 | gnu-bulk | cli, fpm, micro | dynamic against glibc 2.17 |
| macOS x86_64 and arm64 (`aarch64`) | common, bulk, minimal | cli, fpm, micro | n/a |
| Windows x86_64 | spc-min, spc-max | cli, micro | n/a |

The scheduled builds run every 3 days. No embed or frankenphp SAPI is published. There is no Windows ARM64 build, and no Windows fpm (PHP has no fpm on Windows). Old patch releases are kept, but only a short window of them (roughly 3–5 per minor version).

### Cited Findings
- Unix build matrix:
  - php-version: "8.2", "8.3", "8.4", "8.5".
  - Runners: ubuntu-latest, macos-15-intel, ubuntu-24.04-arm, macos-15, ubuntu-22.04, ubuntu-22.04-arm.
  - Combinations: minimal, bulk, common, gnu-bulk.
  - gnu-bulk runs only on ubuntu-22.04 and ubuntu-22.04-arm, with `SPC_TARGET=x86_64-linux-gnu.2.17` or `aarch64-linux-gnu.2.17`. minimal, bulk and common skip the 22.04 runners.
  - Every Unix build passes `--build-cli --build-micro --build-fpm`.
  - Source: [v3-php-bin-unix.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-unix.yml)
- Windows build matrix: php-version 8.2 to 8.5, runner `windows-latest` only, combinations `spc-min` and `spc-max`, with `OS=windows` and `ARCH=x86_64`. The build command is `build --build-cli --build-micro` (no fpm) — [v3-php-bin-windows.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-windows.yml)
- Schedule: both workflows have `workflow_dispatch` plus `schedule: cron: "0 1 */3 * *"`, i.e. 01:00 UTC every third day of the month — [v3-php-bin-unix.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-unix.yml), [v3-php-bin-windows.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-windows.yml)
- The libc of the default (non-gnu) Linux builds is musl. The common set's `build-manifest.json` reports:
  - `"platform": "linux-x86_64"`
  - `"libc": "musl"`
  - `"spc-target": "x86_64-linux-musl"`
  - `"toolchain": "StaticPHP\\Toolchain\\ZigToolchain"`
  - `"spc-version": "3.0.0-alpha1"`
  - Source: [common/build-manifest.json](https://dl.static-php.dev/v3/php-bin/common/build-manifest.json)
- The gnu-bulk README ends with "SPC_TARGET: x86_64-linux-gnu.2.17". The common README reports "SPC_TARGET: default" — [gnu-bulk README](https://dl.static-php.dev/v3/php-bin/gnu-bulk/README.txt), [common README](https://dl.static-php.dev/v3/php-bin/common/README.txt)
- Extension sets (from each set's README.txt):
  - **minimal** (7): iconv, pcntl, posix, mbstring, filter, tokenizer, phar
  - **common** (37): bcmath, bz2, calendar, ctype, curl, dom, exif, fileinfo, filter, ftp, gd, gmp, iconv, xml, mbstring, mbregex, mysqlnd, openssl, pcntl, pdo, pdo_mysql, pdo_sqlite, pdo_pgsql, pgsql, phar, posix, redis, session, simplexml, soap, sockets, sqlite3, tokenizer, xmlwriter, xmlreader, zlib, zip
  - **bulk / gnu-bulk** (56): adds apcu, dba, event, imagick, imap, intl, mysqli, opcache, opentelemetry, protobuf, readline, shmop, sodium, swoole (+ swoole-hook-mysql/pgsql/sqlite), sysvmsg, sysvsem, sysvshm, xsl
  - **spc-min** (Windows, 7): ctype, fileinfo, filter, iconv, mbstring, tokenizer, phar
  - **spc-max** (Windows, 50+): amqp, apcu, bcmath, bz2, calendar, ctype, curl, dba, dom, ds, exif, ffi, fileinfo, filter, ftp, gd, iconv, igbinary, libxml, mbregex, mbstring, mysqli, mysqlnd, opcache, openssl, pdo, pdo_mysql, pdo_sqlite, pdo_sqlsrv, phar, rar, redis, session, shmop, simdjson, simplexml, soap, sockets, sqlite3, sqlsrv, ssh2, sysvshm, tokenizer, xml, xmlreader, xmlwriter, yac, yaml, zip, zlib
  - Sources: [minimal README](https://dl.static-php.dev/v3/php-bin/minimal/README.txt), [common README](https://dl.static-php.dev/v3/php-bin/common/README.txt), [bulk README](https://dl.static-php.dev/static-php-cli/bulk/README.txt), [gnu-bulk README](https://dl.static-php.dev/v3/php-bin/gnu-bulk/README.txt), [spc-min README](https://dl.static-php.dev/v3/php-bin/spc-min/README.txt), [spc-max README](https://dl.static-php.dev/v3/php-bin/spc-max/README.txt)
- Windows version inventory on 2026-11-10. spc-min and spc-max hold the same list, each with cli and micro zips:
  - 8.2.32, 8.2.33, 8.2.35
  - 8.3.32, 8.3.33, 8.3.36
  - 8.4.23, 8.4.24, 8.4.27
  - 8.5.8, 8.5.9, 8.5.12
  - Source: [spc-max JSON](https://dl.static-php.dev/v3/php-bin/spc-max/?format=json), [spc-min JSON](https://dl.static-php.dev/v3/php-bin/spc-min/?format=json)
- Sample sizes on 2026-11-10:

  | File | Size | Uploaded |
  |---|---|---|
  | spc-max `php-8.5.12-cli-win.zip` | 9.6M | 2026-11-10 08:16:41 |
  | spc-min `php-8.5.12-cli-win.zip` | 4.2M | 2026-11-10 08:07:19 |

  Source: [spc-max JSON](https://dl.static-php.dev/v3/php-bin/spc-max/?format=json), [spc-min JSON](https://dl.static-php.dev/v3/php-bin/spc-min/?format=json)
- Linux and macOS inventory for v3 common, cli `linux-x86_64`: 8.2.32–8.2.35, 8.3.32, 8.3.33, 8.3.35, 8.3.36, 8.4.23–8.4.27, 8.5.8–8.5.12 (18 versions). Coverage is uneven:
  - macOS x86_64 common has 14 versions.
  - bulk linux-aarch64 has only 8 (two per minor).
  - Every platform and set has the newest patch of each minor (8.2.35, 8.3.36, 8.4.27, 8.5.12) with a sha256 sidecar.
  - Source: [v3/php-bin/common JSON](https://dl.static-php.dev/v3/php-bin/common/?format=json), [v3/php-bin/bulk JSON](https://dl.static-php.dev/v3/php-bin/bulk/?format=json)
- Upload times: the newest uploads in every v3 set are dated 2026-11-10. The oldest retained files (e.g. `php-8.2.32-cli-linux-aarch64.tar.gz`) are dated 2026-07-19 — [v3/php-bin/bulk JSON](https://dl.static-php.dev/v3/php-bin/bulk/?format=json)
- Legacy v2 tree (historical, not refreshed since 2026-07-07 for Unix and 2026-06-10 for Windows):
  - It keeps much deeper history: Unix `common` runs from 8.0.30 and 8.1.23 up to 8.5.8.
  - Windows `spc-min` runs from 8.0.30 up to 8.5.7 (71 versions). Windows `spc-max` stops at 8.5.5 (2026-05-07).
  - Sources: [legacy common JSON](https://dl.static-php.dev/static-php-cli/common/?format=json), [legacy spc-min JSON](https://dl.static-php.dev/static-php-cli/windows/spc-min/?format=json), [legacy spc-max JSON](https://dl.static-php.dev/static-php-cli/windows/spc-max/?format=json)
- Legacy Windows READMEs and builds carried PHP 8.0 and 8.1. The v3 matrix starts at 8.2 — [legacy spc-max listing](https://dl.static-php.dev/static-php-cli/windows/spc-max/?format=json), [v3-php-bin-windows.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-windows.yml)
- The Windows workflow does not set `--with-suggests` or `--dl-prefer-binary`. The Unix workflow does (`--with-suggests --dl-prefer-binary` appear in the common README's compile command) — [common README](https://dl.static-php.dev/v3/php-bin/common/README.txt), [v3-php-bin-windows.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-windows.yml)

### Inferences
- Gaps in the version lists (e.g. 8.3.34 is missing on linux-x86_64 common, and 8.2.34 on Windows) suggest each run builds only the current patch of each minor, so any patch released and superseded between runs never gets built. A version manager should not assume every upstream PHP patch exists.
- Retention appears to be a rolling window starting around July 2026, when the v3 tree began. Whether old files are ever pruned is unclear, because the tree is only about 4 months old.
- PHP 8.1 and older exist only in the frozen legacy tree, so a client wanting EOL versions has to read both trees.
- No ZTS builds are published (the scheduled workflows have no ZTS input), and there is no embed SAPI. The upstream tool can build embed and frankenphp, but these sets do not include them.

### Gaps
- I found no published policy on how long old patch versions are kept, or on when the legacy `static-php-cli/` tree will be removed.
- There is no Windows aarch64 build, and the project names none as planned.
- Whether the Windows binaries are NTS (thread-safety off) is not stated explicitly. The workflow sets no ZTS flag, which implies NTS (inference).

## Is there a machine-readable index of available builds?

### Takeaway
Yes. Every directory listing on dl.static-php.dev returns JSON when `?format=json` is appended: an array of entries with name, full_path, size, last_modified and download_count. Each Unix set also publishes a `build-manifest.json` describing the build target and packages. There is no single global index of "all versions for all platforms" — a client has to list each set directory.

### Cited Findings
- The HTML listing page has a "JSON Format" link pointing to `?format=json` — [legacy listing HTML](https://dl.static-php.dev/static-php-cli/)
- Example JSON entry, verbatim: `{"is_dir":false,"full_path":"/static-php-cli/windows/spc-max/README.txt","name":"README.txt","size":"802B","last_modified":"2026-04-10 07:46:20","download_count":907,"is_parent":false}` — [spc-max JSON](https://dl.static-php.dev/static-php-cli/windows/spc-max/?format=json)
- Format quirks:
  - `size` is a human-readable string (`"9.6M"`, `"802B"`), not bytes.
  - `last_modified` is `YYYY-MM-DD HH:MM:SS` with no timezone.
  - Directories have `"download_count":""` (a string).
  - Source: [v3/php-bin/spc-max JSON](https://dl.static-php.dev/v3/php-bin/spc-max/?format=json)
- `build-manifest.json` (Unix sets only) has the keys `schema-version` (1), `spc-version`, `target` (platform, os, architecture, libc, libc-version, spc-target, toolchain), `requested-packages`, `packages` and `targets` — [common/build-manifest.json](https://dl.static-php.dev/v3/php-bin/common/build-manifest.json)
- The workflow writes `build-manifest.json`, `license/` and `README.txt` only from the PHP 8.4 job on `ubuntu-latest` or `ubuntu-22.04`. So the manifest describes linux-x86_64 only, not every platform in the set — [v3-php-bin-unix.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-unix.yml)
- The Windows sets have only README.txt, with no manifest and no license dir — [v3/php-bin/spc-min JSON](https://dl.static-php.dev/v3/php-bin/spc-min/?format=json)
- Each set's `license/` folder contains `SUMMARY.json` plus per-dependency `*_LICENSE.txt` files — [v3/php-bin/common/license](https://dl.static-php.dev/v3/php-bin/common/license/?format=json)

### Inferences
- For a Windows-first client, the practical index is `GET https://dl.static-php.dev/v3/php-bin/spc-min/?format=json` (or spc-max), filtered by regex `^php-(\d+\.\d+\.\d+)-(cli|micro)-win\.zip$`, then a check of the `.sha256` sidecar where it exists.
- The JSON format is a feature of the server's listing page, not a documented API, so it may change without notice.

### Gaps
- I found no documentation of the `?format=json` listing in the project docs.
- Client behaviour note: a request with Python's default urllib User-Agent got HTTP 403, while a `curl/8.0` User-Agent and curl's default both worked. Clients should send a normal User-Agent.

## Are the binaries on dl.static-php.dev official project builds, and who operates the host?

### Takeaway
Yes, they are official. The project README links them as its "self-hosted server" for direct downloads. They are built by GitHub Actions in the `static-php/hosted` repo, which belongs to the project's own GitHub org. That repo checks out `crazywhalecc/static-php-cli` ref `v3` and uploads to an S3-compatible bucket ("self-hosted OSS") whose credentials are repository secrets. No public statement names the legal entity that runs the server.

### Cited Findings
- The v3 README says direct-download artifacts are available "from Actions" in `static-php/hosted` (workflows `v3-php-bin-unix.yml` and `v3-php-bin-windows.yml`) "or from a self-hosted server", and links the dl.static-php.dev table — [README (v3 branch)](https://raw.githubusercontent.com/crazywhalecc/static-php-cli/v3/README.md)
- `static-php/hosted` describes itself as "Self-Hosted static-php-cli build action.". It was last pushed 2026-11-01 and is not archived — [GitHub API repos/static-php/hosted](https://api.github.com/repos/static-php/hosted)
- Deployment step, as written in the workflow:
  - Step name: "Deploy to self-hosted OSS".
  - It uses `static-php/upload-s3-action@v1.0.0` with secrets `AWS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_BUCKET` and `AWS_ENDPOINT`.
  - It writes to `destination_dir: v3/php-bin/${{ matrix.combination }}/`.
  - The Windows job checks out `repository: crazywhalecc/static-php-cli` with `ref: v3`.
  - Source: [v3-php-bin-unix.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-unix.yml), [v3-php-bin-windows.yml](https://github.com/static-php/hosted/blob/main/.github/workflows/v3-php-bin-windows.yml)
- The repo homepage field is `https://static-php.dev`, and the listing footer links both static-php.dev and GitHub — [GitHub API](https://api.github.com/repos/crazywhalecc/static-php-cli), [listing HTML](https://dl.static-php.dev/static-php-cli/)
- The builder version recorded in the current manifests is `3.0.0-alpha1`. These builds come from an alpha v3 toolchain, while the latest stable GitHub release is 2.8.5 — [common/build-manifest.json](https://dl.static-php.dev/v3/php-bin/common/build-manifest.json), [GitHub API releases](https://api.github.com/repos/crazywhalecc/static-php-cli/releases)

### Inferences
- The binaries are built by the same people who maintain static-php-cli and published through their own infrastructure. That makes them "official" in practice, but they are offered as "example pre-compiled artifacts", not as supported releases. The README frames them as a convenience next to building your own.
- Because the builds come from an alpha v3 builder and the URL tree has already moved once (`static-php-cli/` to `v3/php-bin/`), a consumer should treat the layout as unstable and keep its base URL configurable.

### Gaps
- I found no public statement of who owns or pays for the dl.static-php.dev server or bucket, and I did not check WHOIS or DNS.
- There are no signatures (GPG or Sigstore), only sha256 sidecars hosted on the same server, so the integrity check does not cover a compromised host.
