# static-php-cli (StaticPHP) prebuilt binaries: build and publish pipeline provenance

All observations were made on 2026-11-10 with `gh api`, shallow clones and HTTP requests. Commits referenced:
- `crazywhalecc/static-php-cli` branch `v3` (the default branch) @ `ff04d4af9ba44f6c194239d733e0529cc6ddecea` (2026-11-09)
- `crazywhalecc/static-php-cli` branch `main` (v2) @ `956fa13e7c390e3127cc0343215c00491f13a835` (2026-08-22)
- `static-php/hosted` branch `master` @ `3e0461b31a2cae5b91cbfcab35567ee6f600ae32`

Abbreviations: SPC = static-php-cli. "OSS" is the project's own word for the object store behind dl.static-php.dev. It is an S3-compatible endpoint.

## Which workflows build and publish the downloadable PHP binaries?

### Takeaway
The main repo does **not** build the PHP binaries on dl.static-php.dev. They come from a separate repo, `static-php/hosted`: `v3-php-bin-unix.yml` and `v3-php-bin-windows.yml` run on a cron every 3 days on **GitHub-hosted** runners. They check out `crazywhalecc/static-php-cli@v3`, build, and push to an S3-compatible bucket using static AWS-style key secrets. The main repo's `release-build.yml` publishes only the `spc` builder tool. That workflow, unlike the PHP binary workflows, also generates GitHub build-provenance attestations.

### Cited Findings
- The main repo's workflows are: `build-unix.yml`, `build-windows-x86_64.yml`, `ext-matrix-tests.yml`, `post-test-bot-comment.yml`, `release-build.yml`, `tests.yml` and `vitepress-deploy.yml`. `build-unix.yml` and `build-windows-x86_64.yml` are `workflow_dispatch` "build online" workflows that upload only as `actions/upload-artifact`, with no deploy step — [static-php-cli .github/workflows @ v3](https://github.com/crazywhalecc/static-php-cli/tree/v3/.github/workflows)
- The README's "Direct Download" table links `https://dl.static-php.dev/v3/php-bin/{common,bulk,gnu-bulk,minimal,spc-min,spc-max}/`. It says artifacts can be downloaded "from [Actions](https://github.com/static-php/hosted/actions/workflows/v3-php-bin-unix.yml) … or from a self-hosted server" — [README.md @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/README.md)
- `static-php/hosted` describes itself as "Self-Hosted [StaticPHP] build action. … used to automatically compile StaticPHP related content for different architectures and operating systems." It has no license file (the API returns `license: null`) — [static-php/hosted README](https://github.com/static-php/hosted)
- `static-php/hosted/.github/workflows/v3-php-bin-unix.yml` ("[v3] Build Self-Hosted PHP Binary (Unix)"):
  - Triggers: `workflow_dispatch` and `schedule: cron: "0 1 */3 * *"`.
  - Matrix: PHP `8.2`–`8.5`; runners `ubuntu-latest`, `macos-15-intel`, `ubuntu-24.04-arm`, `macos-15`, `ubuntu-22.04`, `ubuntu-22.04-arm`; combinations `minimal`, `bulk`, `common`, `gnu-bulk`.
  - Checkout step: `repository: crazywhalecc/static-php-cli` with `ref: v3`. This is a branch, not a pinned commit or tag.
  - Build: `bin/spc build --build-cli --build-micro --build-fpm "<exts>" --debug [--with-upx-pack] [--with-suggests] --dl-with-php="<ver>" --dl-retry=5 --dl-prefer-binary --dl-ignore-cache=php-src`.
  - Publish step: `name: "Deploy to self-hosted OSS"`, `uses: static-php/upload-s3-action@v1.0.0`, `with: aws_key_id: ${{ secrets.AWS_KEY_ID }}`, `aws_secret_access_key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}`, `aws_bucket: ${{ secrets.AWS_BUCKET }}`, `source_dir: "dist/"`, `destination_dir: v3/php-bin/${{ matrix.combination }}/`, `endpoint: ${{ secrets.AWS_ENDPOINT }}`.
  - It also uses `actions/cache@v4` for `downloads` (the source cache) and for `vendor`.
  - It has no attestation or signing step — [v3-php-bin-unix.yml](https://github.com/static-php/hosted/blob/master/.github/workflows/v3-php-bin-unix.yml)
- The "Generate SHA-256 checksums" step writes a `<archive>.sha256` sidecar next to each archive. It was added on 2026-10-23 in commit `66cd3e63` ("Add SHA-256 checksum generation for build artifacts in CI workflows"). The workflow was renamed from `build-php-unix.yml` to `v3-php-bin-unix.yml` on 2026-07-13 (`dc8650d1`) — [commit history of v3-php-bin-unix.yml](https://github.com/static-php/hosted/commits/master/.github/workflows/v3-php-bin-unix.yml)
- The "Add build metadata" step runs only for PHP 8.4 on ubuntu-latest or ubuntu-22.04. It copies `buildroot/license`, `buildroot/build-manifest.json` and a `README.txt` that lists the extensions and the exact compile command — [v3-php-bin-unix.yml](https://github.com/static-php/hosted/blob/master/.github/workflows/v3-php-bin-unix.yml)
- `v3-php-bin-windows.yml` uses the `windows-latest` runner, the combinations `spc-min` and `spc-max`, the same `static-php/upload-s3-action@v1.0.0` deploy to `v3/php-bin/${{ matrix.combination }}/`, and the same sidecar checksums — [v3-php-bin-windows.yml](https://github.com/static-php/hosted/blob/master/.github/workflows/v3-php-bin-windows.yml)
- **The runners are GitHub-hosted, not self-hosted.** The jobs of the latest successful run report labels such as `["ubuntu-latest"]`, `["ubuntu-24.04-arm"]` and `["ubuntu-22.04-arm"]`, with runner name `GitHub Actions 10001159xx` and runner group `GitHub Actions` (from `gh api repos/static-php/hosted/actions/runs/<id>/jobs`). The two most recent scheduled runs (2026-11-07 and 2026-11-10) ended in `failure`, and the 2026-11-04 run succeeded — [hosted Actions runs](https://github.com/static-php/hosted/actions/workflows/v3-php-bin-unix.yml)
- The main repo's `release-build.yml` ("Build SPC Binary") builds the `spc` builder itself:
  - Triggers: push to `main`/`v3`, release `published`, and `workflow_dispatch`.
  - Runners are GitHub-hosted (`ubuntu-latest`, `macos-latest`).
  - It has `permissions: id-token: write, attestations: write` and a step `"Generate build provenance attestation"` with `uses: actions/attest-build-provenance@v4`.
  - It deploys with `static-php/upload-s3-action@v1.0.0` to `v3/spc-bin/nightly/` (on the v3 branch), `v3/spc-bin/latest/` and `v3/spc-bin/${{ github.ref_name }}/` (on tags), each guarded by `if: github.repository == 'crazywhalecc/static-php-cli'`.
  - It also attaches the binaries to GitHub Releases through `softprops/action-gh-release@v1`.
  - It bootstraps by downloading `https://dl.static-php.dev/static-php-cli/minimal/php-8.4.11-micro-<os>.tar.gz` (or the windows `spc-min` zip) with `curl -fsSL`, with no checksum check visible in the step — [release-build.yml @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/.github/workflows/release-build.yml)
- `static-php/upload-s3-action` is a fork of `shallwefootball/upload-s3-action` ("Customized with single-file upload"), last pushed 2024-08-18 — [static-php/upload-s3-action](https://github.com/static-php/upload-s3-action)
- `static-php/hosted/.github/workflows/download-cache.yml` ("Mirror sources to dl.static-php.dev") runs on the same 3-day cron. It checks out `crazywhalecc/static-php-cli` `ref: main` (v2), downloads every source and package in `config/source.json` and `config/pkg.json`, and uploads them with **`shallwefootball/s3-upload-action@master`**, a third-party action on a mutable `master` ref that receives the AWS secrets. The destination is `static-php-cli/deps/spc-download-mirror/<pkg>/` — [download-cache.yml](https://github.com/static-php/hosted/blob/master/.github/workflows/download-cache.yml)
- dl.static-php.dev answers with `Server: cloudflare` and `cf-cache-status: DYNAMIC`. The legacy v2 path `https://dl.static-php.dev/static-php-cli/common/` still returns 200 (from `curl -I`).
- The bulk directory listing shows `php-8.4.27-*.tar.gz.sha256` sidecars, but older files (8.4.23, 8.4.24) have none. There are no signature or attestation files — [dl.static-php.dev/v3/php-bin/bulk/](https://dl.static-php.dev/v3/php-bin/bulk/)

### Inferences
- The trust root for the dl.static-php.dev PHP binaries is: the `static-php/hosted` workflow, the mutable `v3` branch of the main repo at build time, GitHub-hosted runners, and whoever holds the `AWS_*` secrets and the bucket. Anyone with bucket write credentials can replace a file outside CI, and nothing cryptographic would detect it. The `.sha256` sidecars sit on the same host, so they detect corruption but not tampering.
- The two `shallwefootball/s3-upload-action@master` uses expose the same bucket credentials (assuming the secret names map to the same bucket) to a third party's mutable code. This is a supply-chain weak point. It is in the source-mirror workflow, not the PHP binary workflow, but a stolen key would likely grant write access to the whole bucket. That last part is an inference: the bucket's IAM scoping is not visible.
- The `spc` tool binaries have GitHub attestations, which can be checked with `gh attestation verify`. The PHP binaries do not.
- Workflow runs in the public repo give partial provenance: the commit SHA and the logs. Because the build checks out a branch, the exact SPC commit used for a given file must be found in that run's checkout log.

### Gaps
- The IAM scope of the AWS keys, the S3 provider behind `AWS_ENDPOINT`, and whether the bucket has versioning or object-lock are not visible.
- I did not check the full history of hosted workflows for v2-era files such as `build-php-common.yml`. The deletions found were `build-pkg-unix.yml` (2025-09-04) and the rename on 2026-07-13. How the legacy `/static-php-cli/{common,bulk,minimal}/` v2 paths are produced today was not confirmed.
- I did not verify whether the `.sha256` contents match the archives.

## Are downloaded sources (PHP tarballs, library sources) hash- or signature-verified?

### Takeaway
Only partly. In v3, the PHP tarball from php.net is SHA-256-checked against php.net's release JSON. GitHub Release assets are checked against GitHub's API `digest` when one exists. All other source types (git clones, GitHub tarballs, file-list scrapes, plain URLs, PECL, and the prebuilt library binaries from `static-php/package-bin`) have **no hash or signature verification**, and no hashes are pinned in config. GPG signatures are never checked.

### Cited Findings
- **PHP source.** `config/artifact/php-src.yml` sets `source: type: php-release, domain: 'https://www.php.net'` and `source-mirror: type: php-release, domain: 'https://phpmirror.static-php.dev'` — [php-src.yml @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/config/artifact/php-src.yml)
- **How the PHP check works.** `src/StaticPHP/Artifact/Downloader/Type/PhpRelease.php` fetches `{domain}/releases/index.php?json&version={v}`, takes the `sha256` of the `.tar.xz` entry, downloads `{domain}/distributions/php-{v}.tar.xz`, and in `validate()` fails on a mismatch ("SHA256 checksum mismatch …") or when the checksum is missing.
  - The check is skipped (`$this->sha256 = null` → "skipping validation") when the version is `git`, which clones `php-src` `master`.
  - It is also skipped when php.net has no release, in which case it falls back to a `PhpTag` git tag archive.
  - Source: [PhpRelease.php @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/src/StaticPHP/Artifact/Downloader/Type/PhpRelease.php)
- **GitHub Release assets.** `GitHubRelease.php` reads `asset['digest']` (`sha256:` prefix) from the GitHub API and compares it with `hash_file('sha256', …)`. If no digest exists it logs "No sha256 digest found … skipping hash validation" — [GitHubRelease.php @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/src/StaticPHP/Artifact/Downloader/Type/GitHubRelease.php)
- **Which types have a validator.** Only `GitHubRelease` and `PhpRelease` implement `ValidatorInterface` (from `grep 'implements.*ValidatorInterface' src`). `ArtifactDownloader.php` around line 619 runs `validate()` only "if possible", meaning only when the download type is a `ValidatorInterface` — [ArtifactDownloader.php @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/src/StaticPHP/Artifact/Downloader/ArtifactDownloader.php)
- **Which source types the config uses.** Counts across `config/pkg` and `config/artifact` @ v3:
  - `ghrel` 35 (digest-verified when available)
  - `php-release` 2 (verified)
  - `ghtar` 25, `git` 23, `custom` 23, `pie` 21, `filelist` 21, `ghtagtar` 18, `url` 16, `pecl` 6 (no validator)
  - Example: `openssl.yml` uses `ghrel` from `openssl/openssl`, with a `filelist` mirror that scrapes `https://www.openssl.org/source/`.
  - No `sha256` or hash fields appear in any config file.
  - Source: [config/pkg @ v3](https://github.com/crazywhalecc/static-php-cli/tree/v3/config/pkg)
- **The local cache.** `ArtifactCache.php` records `sha1_file()` of each download, or the git `rev-parse HEAD`, in a lock file. It uses this only to check that the cache has not changed (`compare_hash`), not to check authenticity against a published value — [ArtifactCache.php @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/src/StaticPHP/Artifact/ArtifactCache.php)
- **Prebuilt library binaries.** `HostedPackageBin.php` downloads them from the latest GitHub release of `static-php/package-bin` by asset name, and does not implement a validator. The hosted PHP builds pass `--dl-prefer-binary`, which (by its name and the docs' "Prefer pre-built binaries") pulls these where available — [HostedPackageBin.php @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/src/StaticPHP/Artifact/Downloader/Type/HostedPackageBin.php); [package-bin repo](https://github.com/static-php/package-bin)
- **Mirror fallback.** By default (`alt = true`) the downloader queues `source-mirror` and `binary-mirror` entries after the primary source fails. `--no-alt` turns this off — [ArtifactDownloader.php @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/src/StaticPHP/Artifact/Downloader/ArtifactDownloader.php)
- **What the docs say.**
  - "`php-release` … Download official PHP source from php.net … SHA256 integrity is verified automatically." — [docs/en/develop/artifact-model.md @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/docs/en/develop/artifact-model.md)
  - `llvm-tools` binaries from `dl.static-php.dev/v3/deps/llvm-tools/` are "verified against the published SHA-256 checksum".
  - The compiler-rt sources come from `dl.static-php.dev/v3/deps/compiler-rt/` ("That archive is the only source"), and the docs claim no verification for them — [docs/en/develop/system-build-tools.md @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/docs/en/develop/system-build-tools.md)
- **The v2 branch (`main`).** A grep for sha256, checksum, gpg or signature in `src/SPC` found only `LockFile.php` and `DirDiff.php` plus unrelated builder hits. No source-authenticity verification was found in the v2 downloader (from my own grep of the `main` clone; I did not read every hit in full).

### Inferences
- When the mirror fallback is used, `phpmirror.static-php.dev` serves both the release JSON and the tarball. The SHA-256 then comes from the same project-controlled host as the file, so the check no longer anchors trust in php.net.
- Most third-party library sources are trusted over TLS alone (git, GitHub tarballs, scraped URLs). Prebuilt library binaries from `static-php/package-bin` and toolchain pieces from dl.static-php.dev add another project-controlled trust hop.

### Gaps
- I did not inspect the `custom` download callbacks (23) one by one for ad-hoc verification. A grep showed hash-related code in `go_win.php`, `go_xcaddy.php`, `zig.php`, `llvm_tools.php` and `msys2_build_essentials.php`, which suggests those toolchains are checked. Not verified.
- I did not confirm how `static-php/package-bin` releases are built (which workflow, and whether they are attested).

## Who runs dl.static-php.dev?

### Takeaway
No formal statement names the operator. The README says sponsorship donations to the lead maintainer, Jerry Ma (`crazywhalecc`), partly fund "the static-php.dev server", and the bucket is written by workflows in his org. Inference: the server is run personally by the maintainer or the `static-php` org, behind Cloudflare. There is no separate "official" vs "community" download host. Everything is labelled "self-hosted".

### Cited Findings
- "You can sponsor me or my project from GitHub Sponsor. A portion of your donation will be used to maintain the **static-php.dev** server." — [README.md @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/README.md) (the same text is in the v2 `main` README)
- The workflows call the target "self-hosted OSS". The main repo's deploy steps are gated on `github.repository == 'crazywhalecc/static-php-cli'` — [release-build.yml @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/.github/workflows/release-build.yml)
- The `static-php` GitHub org ("StaticPHP", blog `https://staticphp.dev/`, created 2023-10-22) has the public members `crazywhalecc`, `henderkes` and `pronskiy` — [github.com/static-php](https://github.com/static-php)
- The host sits behind Cloudflare (`Server: cloudflare`, from `curl -I`). The listing page does not identify an operator — [dl.static-php.dev](https://dl.static-php.dev/v3/php-bin/bulk/)
- The project names project-controlled hosts beyond dl: `phpmirror.static-php.dev` (the PHP source mirror) and the docs at `static-php.dev` — [php-src.yml](https://github.com/crazywhalecc/static-php-cli/blob/v3/config/artifact/php-src.yml); [README](https://github.com/crazywhalecc/static-php-cli/blob/v3/README.md)
- The README offers two download routes: GitHub Actions artifacts from `static-php/hosted`, which are produced by the same runs, and "a self-hosted server". It does not separate official from community builds — [README.md @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/README.md)

### Inferences
- The GitHub Actions artifacts (`actions/upload-artifact@v4`, uploaded in the same job) are an alternative channel that skips the S3 bucket. They expire, though: GitHub's default retention is 90 days.

### Gaps
- I did not do a WHOIS or registrant lookup for static-php.dev, which would be privacy-redacted for .dev anyway. There is no ToS, operator page or SLA for the host.
- The relationship between `staticphp.dev` (the org blog URL) and `static-php.dev` was not explored.

## Security incidents, security policy, governance

### Takeaway
There is no SECURITY.md, and GitHub private vulnerability reporting is **disabled** on both the main and hosted repos. There are zero published security advisories. A search found no reported compromise of builds. The project is MIT-licensed, owned by a personal GitHub account (`crazywhalecc`, Jerry Ma), and in practice run by two people (crazywhalecc and henderkes).

### Cited Findings
- **No security policy file.** There is no `SECURITY.md` at the repo root or in `.github/` @ v3. `.github/` holds `ISSUE_TEMPLATE/`, `workflows/`, `FUNDING.yml`, `copilot-instructions.md` and `pull_request_template.md`. The org `static-php/.github` repo holds only `README.md` and `profile` — [static-php-cli .github @ v3](https://github.com/crazywhalecc/static-php-cli/tree/v3/.github); [static-php/.github](https://github.com/static-php/.github)
- **Contribution docs on disclosure.** The docs say: "Do not publish exploit details … Use GitHub's private vulnerability reporting for the repository when available, or contact the maintainers through an existing project channel". However, `gh api repos/crazywhalecc/static-php-cli/private-vulnerability-reporting` returns `{"enabled":false}`, and so does the same call for `static-php/hosted` — [docs/en/contributing/index.md @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/docs/en/contributing/index.md)
- **Advisories.** `gh api repos/crazywhalecc/static-php-cli/security-advisories` returns 0 advisories.
- **Issue search.** A search for "security" in issues found no incident reports, only build or CVE-dependency topics. Examples are "musl 1.2.5 CVE" (#617, closed, 2025-03) and "Security & Debug concerning: add static-php-cli.version for php -i" (#325, 2024-02) — [issue #617](https://github.com/crazywhalecc/static-php-cli/issues/617); [issue #325](https://github.com/crazywhalecc/static-php-cli/issues/325)
- **PHP CVE patching.** The docs describe patching EOL PHP 7.4, 8.0 and 8.1 sources with "the PHP security team's official minimal backports" for CVE-2026-109618/109619. For 8.2 and later they say to use the patched releases (8.2.35, 8.3.36, 8.4.27, 8.5.12 and later) — [docs/en/develop/php-src-changes.md @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/docs/en/develop/php-src-changes.md)
- **Ownership and license.**
  - The repo owner type is `User` (`crazywhalecc`), not an org.
  - The license is MIT ("Copyright (c) 2022-2023 Jerry Ma").
  - The repo has about 1,967 stars.
  - The `static-php/hosted` repo has no license.
  - Source: [LICENSE @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/LICENSE)
- **Top contributors.** crazywhalecc 2644, henderkes 1314, dunglas 54 (the FrankenPHP author), jingjingxyk 48, mhpcc 39 and stloyd 24 — [contributors](https://github.com/crazywhalecc/static-php-cli/graphs/contributors)
- **Who changes the hosted workflows.** Recent commits to `v3-php-bin-unix.yml` are by crazywhalecc / "Jerry Ma" — [hosted commits](https://github.com/static-php/hosted/commits/master/.github/workflows/v3-php-bin-unix.yml)
- **Release status.** v3 is the default branch and the project is renamed "StaticPHP", but the README still says "Stay tuned for the official release". v2 remains on `main` — [README.md @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/README.md)
- **License of the binaries themselves.** The produced binaries bundle third-party libraries under their own licenses. SPC records them (`metadata.license`, `license-files`), and the hosted workflow publishes `buildroot/license` only for the PHP 8.4 ubuntu jobs — [php-src.yml](https://github.com/crazywhalecc/static-php-cli/blob/v3/config/artifact/php-src.yml); [v3-php-bin-unix.yml](https://github.com/static-php/hosted/blob/master/.github/workflows/v3-php-bin-unix.yml)

### Inferences
- The bus factor is about 2, and the main repo sits on a personal account, so account compromise or abandonment is a single-person risk.
- The docs point to private vulnerability reporting, but it is disabled, so there is no working private disclosure channel today.

### Gaps
- I found no reliable sources on past compromised builds, and I did not search Discord or the GitHub discussions in depth. Absence of evidence only.
- Whether branch protection or required reviews apply to `v3` or to `static-php/hosted` `master` is not visible without admin access.

## Are builds reproducible?

### Takeaway
No reproducibility guarantee was found, and the pipeline's design works against it.

### Cited Findings
- **The build inputs change.** The builds check out a moving branch (`ref: v3`), take the latest upstream versions (for example `ghrel` with `prefer-stable: true`, `filelist` "automatically selects and downloads the highest stable version"), take the latest `package-bin` release, and on Linux UPX-pack the binaries — [v3-php-bin-unix.yml](https://github.com/static-php/hosted/blob/master/.github/workflows/v3-php-bin-unix.yml); [artifact-model.md](https://github.com/crazywhalecc/static-php-cli/blob/v3/docs/en/develop/artifact-model.md); [HostedPackageBin.php](https://github.com/crazywhalecc/static-php-cli/blob/v3/src/StaticPHP/Artifact/Downloader/Type/HostedPackageBin.php)
- **No reproducible-build support in the code.** A grep for `SOURCE_DATE_EPOCH`, "reproducib" or "deterministic" in `src/`, `config/` and `docs/en` @ v3 found only performance-doc wording ("reproducible musl/glibc selection" for Zig, and reproducible benchmark methodology). There is no reproducible-build mechanism — [docs/en/develop/performance.md @ v3](https://github.com/crazywhalecc/static-php-cli/blob/v3/docs/en/develop/performance.md)
- **What a user can recover.** `build-manifest.json` and `README.txt`, with the exact build command, are published for some jobs, which allows an approximate rebuild — [v3-php-bin-unix.yml](https://github.com/static-php/hosted/blob/master/.github/workflows/v3-php-bin-unix.yml)

### Inferences
- An independent bit-for-bit rebuild is not realistic. A user who wants to trust the binary should build with SPC themselves, pinning the commit and using `--no-alt`, or use the GitHub Actions artifacts from a specific run, whose commit and logs can be traced.

### Gaps
- I did not inspect what `build-manifest.json` contains, such as whether it records the versions or hashes of each source.
