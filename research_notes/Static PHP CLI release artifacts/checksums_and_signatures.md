# static-php-cli: integrity and authenticity material for prebuilt binaries

All observations were made live on **2026-11-10 (UTC ~18:43-18:50)** with `curl` and the `gh` CLI. "Observed" means I fetched it. "Inference" means I reasoned from what I fetched. Directory listings were checked by parsing every `href` on each listing page. The listing also has a JSON form (`?format=json`). Its fields are `full_path, is_dir, download_count, name, size, is_parent, last_modified`, and none of them is a hash.

**Two download trees exist and they differ.** The legacy (v2) tree under `https://dl.static-php.dev/static-php-cli/` has no checksums. The new v3 tree under `https://dl.static-php.dev/v3/` has a `.sha256` sidecar file next to the newest archive of each PHP minor version. Neither tree has signatures, and the PHP binaries have no attestations. Only the `spc` builder tool has GitHub build-provenance attestations.

## Does dl.static-php.dev serve .sha256 / .sha512 / SHA256SUMS files next to binaries?

### Takeaway
- **Legacy tree (`/static-php-cli/{common,bulk,gnu-bulk,minimal,windows/spc-max,windows/spc-min}/`):** there are no checksum files at all.
- **v3 tree (`/v3/php-bin/{common,bulk,gnu-bulk,minimal,spc-max,spc-min}/`):** each archive in the newest patch release of each minor has a per-archive `<archive>.sha256` sidecar. The format is `<64-hex>  <filename>`, which `sha256sum -c` accepts. There is no SHA512 and no SHA256SUMS aggregate file. Older archives in the v3 tree have no sidecar.

### Cited Findings
**Legacy tree (no checksums)**
- The root `https://dl.static-php.dev/static-php-cli/` lists these subdirectories: `bulk/ common/ deps/ gnu-bulk/ minimal/ pre-built/ spc-bin/ windows/`. [listing](https://dl.static-php.dev/static-php-cli/)
- File counts from the listing pages:

  | Directory | Contents |
  |---|---|
  | `common/` | 1014 `.tar.gz`, `README.txt`, `build-extensions.json`, `build-libraries.json`, `license/` |
  | `bulk/` | 921 `.tar.gz` |
  | `minimal/` | 978 `.tar.gz` |
  | `gnu-bulk/` | 207 `.tar.gz` |
  | `windows/spc-max/` | 106 `.zip` |
  | `windows/spc-min/` | 142 `.zip` |

  None of them has a `.sha256`, `.sha512`, `.asc`, `.sig`, `.minisig` or `*SUMS*` file. Example filename: `php-8.5.8-cli-linux-x86_64.tar.gz`. [common](https://dl.static-php.dev/static-php-cli/common/), [bulk](https://dl.static-php.dev/static-php-cli/bulk/), [minimal](https://dl.static-php.dev/static-php-cli/minimal/), [gnu-bulk](https://dl.static-php.dev/static-php-cli/gnu-bulk/), [windows/spc-max](https://dl.static-php.dev/static-php-cli/windows/spc-max/), [windows/spc-min](https://dl.static-php.dev/static-php-cli/windows/spc-min/)
- Guessed sibling URLs all return **HTTP 404**:
  - `https://dl.static-php.dev/static-php-cli/common/php-8.5.8-cli-linux-x86_64.tar.gz` + `.sha256`, `.sha256sum`, `.sha512`, `.asc`, `.sig`, `.minisig`
  - `.../common/SHA256SUMS`, `.../common/sha256sums.txt`, `.../common/checksums.txt`
  - [probed base URL](https://dl.static-php.dev/static-php-cli/common/)
- The legacy `README.txt` lists only the extensions and the `bin/spc build ...` command. It says nothing about hashes. [README](https://dl.static-php.dev/static-php-cli/common/README.txt)
- A user confirmed the same absence in issue #1245 (2026-09-28): "no `<file>.sha256`, no `SHA256SUMS` per directory, and nothing in the listing or `README.txt`". [issue #1245](https://github.com/crazywhalecc/static-php-cli/issues/1245)

**v3 tree (`.sha256` sidecars)**
- The root `https://dl.static-php.dev/v3/` lists `deps/ php-bin/ spc-bin/ tools/`. `v3/php-bin/` lists `bulk/ common/ gnu-bulk/ minimal/ spc-max/ spc-min/`. [v3](https://dl.static-php.dev/v3/), [v3/php-bin](https://dl.static-php.dev/v3/php-bin/)
- Sidecar counts from the listing pages:

  | Directory | Archives | `.sha256` files |
  |---|---|---|
  | `v3/php-bin/common/` | 195 `.tar.gz` | 48 |
  | `bulk/` | 132 | 48 |
  | `minimal/` | 216 | 48 |
  | `gnu-bulk/` | 72 | 24 |
  | `spc-max/` (Windows) | 24 `.zip` | 8 `.zip.sha256` |
  | `spc-min/` (Windows) | 24 `.zip` | 8 `.zip.sha256` |

  [v3/php-bin/common](https://dl.static-php.dev/v3/php-bin/common/), [v3/php-bin/spc-max](https://dl.static-php.dev/v3/php-bin/spc-max/)
- In `common/`, the sidecars exist only for PHP 8.2.35, 8.3.36, 8.4.27 and 8.5.12, covering cli, fpm and micro on linux and macOS, aarch64 and x86_64. That is 4 x 3 x 4 = 48. Older patch versions in the same directory have none. [v3/php-bin/common](https://dl.static-php.dev/v3/php-bin/common/)
- Format sample from `https://dl.static-php.dev/v3/php-bin/common/php-8.5.12-cli-linux-x86_64.tar.gz.sha256`:
  - Content-Type `text/plain`, 101 bytes.
  - Content: `abe474d2b55451653917b87e5fca5455e1d8c2a3fc690cb8e9d8f1fa0da62eec  php-8.5.12-cli-linux-x86_64.tar.gz` (lowercase hex, two spaces, then the bare filename).
  - [sample](https://dl.static-php.dev/v3/php-bin/common/php-8.5.12-cli-linux-x86_64.tar.gz.sha256)
- The sidecars come from CI in the separate repo `static-php/static-php-cli-hosted`:
  - Workflow `v3-php-bin-unix.yml` has the step "Generate SHA-256 checksums". It writes `printf '%s  %s\n' "$(sha256_of "$archive")" "$archive" > "$archive.sha256"`, then self-checks with `sha256sum -c --strict`.
  - A comment in that step explains the per-file choice: matrix jobs share one OSS prefix, so a single shared sums file would be overwritten.
  - `v3-php-bin-windows.yml` does the same with `Get-FileHash -Algorithm SHA256`.
  - The step was added in commit `66cd3e63` on 2026-10-23, "Add SHA-256 checksum generation for build artifacts in CI workflows".
  - [unix workflow](https://github.com/static-php/static-php-cli-hosted/blob/HEAD/.github/workflows/v3-php-bin-unix.yml), [windows workflow](https://github.com/static-php/static-php-cli-hosted/blob/HEAD/.github/workflows/v3-php-bin-windows.yml), [commit history](https://github.com/static-php/static-php-cli-hosted/commits/HEAD/.github/workflows/v3-php-bin-unix.yml)
- The per-directory `build-manifest.json` (schema-version 1, `spc-version: 3.0.0-alpha1`) contains no `sha`, `hash` or `digest` field. I checked this by grepping the fetched file. [manifest](https://dl.static-php.dev/v3/php-bin/common/build-manifest.json)

**Storage backend (HTTP headers)**
- A binary download goes through two redirects: first a 302 to `/down?path=...`, then a 302 to `https://static-php-cli.fra1.digitaloceanspaces.com/static-php-cli/common/php-8.5.8-cli-linux-x86_64.tar.gz` (DigitalOcean Spaces, S3-compatible).
- The response carries `etag: "0416a13b03026c9eac6d23e8af825e98-3"`. The `-3` suffix marks a multipart-upload ETag, so it is not an MD5 of the file. No `x-amz-checksum-*` or `Content-MD5` header was present. [download URL](https://dl.static-php.dev/static-php-cli/common/php-8.5.8-cli-linux-x86_64.tar.gz)

### Inferences
- Sidecars appeared only on archives built or re-uploaded after 2026-10-23, which explains why only the newest patch per minor has them. Legacy-tree archives were apparently not backfilled.
- The `.sha256` file is served from the same origin and the same TLS channel as the archive. It protects against corruption and truncation. It does not protect against a compromised host or bucket.

### Gaps
- I did not download a full archive to confirm that a sidecar hash matches its archive. The format and the CI self-check were verified, but no end-to-end match was.
- I did not list `v3/deps/`, `v3/tools/` or legacy `deps/` and `pre-built/` (library tarballs) for checksums. In the legacy `pre-built/` listing, no checksum-like filenames appeared among its 202 `.txz`/`.tgz` files.

## Do GitHub Releases carry checksum or signature assets? (spc tool vs PHP binaries)

### Takeaway
GitHub Releases contain **only the `spc` builder tool**, never PHP binaries. They carry no checksum or signature assets. The only digests are the ones GitHub itself computes for each asset (`digest: sha256:...` in the API).

### Cited Findings
- The Releases API returned 64 releases. Across all of them the asset types are 230 `.tar.gz`, 51 `.exe` and 1 `.tgz`. No asset name contains sha, sum, sig, asc, intoto, sigstore, att or pem. [Releases API](https://api.github.com/repos/crazywhalecc/static-php-cli/releases?per_page=100)
- The latest release is `2.8.5` (published 2026-04-18). Its assets are `spc-linux-aarch64.tar.gz`, `spc-linux-x86_64.tar.gz`, `spc-macos-aarch64.tar.gz`, `spc-macos-x86_64.tar.gz` and `spc-windows-x64.exe`, which are all spc tool builds. [Releases API](https://api.github.com/repos/crazywhalecc/static-php-cli/releases)
- 100 assets have a populated API `digest` field, for example `spc-windows-x64.exe` in 2.8.5 has `sha256:425b54ab857e21409c1fd9b818899ffebabd1e2817ef0a0ed5ae8a3d9f5b463b`. GitHub computes these server-side. The maintainers do not publish them. [Releases API](https://api.github.com/repos/crazywhalecc/static-php-cli/releases)
- The release workflow uploads only `dist/spc.phar` and the spc archives (`softprops/action-gh-release@v1`). No checksum file is generated for the release. [release-build.yml](https://github.com/crazywhalecc/static-php-cli/blob/v3/.github/workflows/release-build.yml)
- The PHP binaries are built in `static-php/static-php-cli-hosted` and pushed to the S3/OSS bucket behind dl.static-php.dev, not to GitHub Releases. See the workflows above.

### Inferences
- If you are pulling PHP binaries, GitHub Releases are irrelevant. The API `digest` only helps for the spc tool.

### Gaps
- None material.

## Is there any published signing key, attestation, or Sigstore usage?

### Takeaway
- **No GPG, minisign or cosign signatures and no published signing key** exist for anything I checked.
- **GitHub artifact attestations (SLSA build provenance via Sigstore) exist only for the `spc` tool binary.** They started around June 2026, and 322 attestations are listed. **PHP binaries have no attestations.**

### Cited Findings
**spc tool (attestations exist)**
- On the default branch `v3`, `release-build.yml` grants `id-token: write` and `attestations: write`.
- Its step "Generate build provenance attestation" uses `actions/attest-build-provenance@v4` on `spc` (or `spc.exe` on Windows). The step is skipped on pull requests.
- The permissions were added in commit `3ff9426e` on 2026-06-04.
- [release-build.yml](https://github.com/crazywhalecc/static-php-cli/blob/v3/.github/workflows/release-build.yml), [history](https://github.com/crazywhalecc/static-php-cli/commits/v3/.github/workflows/release-build.yml)
- The repo's attestations page shows `totalCount: 322`. Subject names are only `"spc"` and `"spc.exe"`. [attestations](https://github.com/crazywhalecc/static-php-cli/attestations)
- The attestation subject is the **raw binary** (`spc` / `spc.exe`), not the `.tar.gz` that is distributed. A user therefore has to extract the archive before running `gh attestation verify spc --repo crazywhalecc/static-php-cli`. [release-build.yml](https://github.com/crazywhalecc/static-php-cli/blob/v3/.github/workflows/release-build.yml)
- Querying `GET /repos/crazywhalecc/static-php-cli/attestations/sha256:425b54ab...` (the 2.8.5 `spc-windows-x64.exe` digest) returns **404**. This fits the timeline: 2.8.5 (April 2026) predates the attestation step (June 2026). [API](https://api.github.com/repos/crazywhalecc/static-php-cli/attestations/sha256:425b54ab857e21409c1fd9b818899ffebabd1e2817ef0a0ed5ae8a3d9f5b463b)

**No signing tools anywhere**
- In the main repo, a grep of all 7 workflows found no `cosign`, `sigstore` action, `gpg`, `minisign`, `signtool` or `codesign`. The workflows are `build-unix`, `build-windows-x86_64`, `ext-matrix-tests`, `post-test-bot-comment`, `release-build`, `tests` and `vitepress-deploy`. The only `sha256sum` hit is a cache-key hash in `build-windows-x86_64.yml`. [workflows](https://github.com/crazywhalecc/static-php-cli/tree/v3/.github/workflows)
- In `static-php/static-php-cli-hosted`, a grep of `v3-php-bin-unix.yml` and `v3-php-bin-windows.yml` found only the SHA-256 steps. There was no attest, cosign, gpg, minisign, signtool, SBOM or `id-token` hit. [hosted workflows](https://github.com/static-php/static-php-cli-hosted/tree/HEAD/.github/workflows)

**Nightly spc builds**
- `https://dl.static-php.dev/v3/spc-bin/nightly/README.txt` says: "We don't support any hash verification for nightly build." [README](https://dl.static-php.dev/v3/spc-bin/nightly/README.txt)
- That directory holds raw `spc-*` binaries, `.tar.gz` archives, `spc-windows-x64.exe`, `spc.phar` and the README. It has no checksum files. [listing](https://dl.static-php.dev/v3/spc-bin/nightly/)

### Inferences
- Nightly spc binaries built on v3 pushes after 2026-06-04 should have matching GitHub attestations, because the step runs on every non-PR event. I did not verify a specific nightly digest against the attestation API.

### Gaps
- I did not run `gh attestation verify` end-to-end, because that requires downloading a full binary.
- I did not search for a signing key in keyservers, the website or the repo's SECURITY.md. None was referenced anywhere I looked.

## Are Windows .exe files Authenticode-signed?

### Takeaway
- **The spc tool `.exe`:** not signed. Observed directly from the PE header.
- **The PHP `php.exe` inside the `.zip` archives:** not verified. Nothing in the workflows signs it, and the maintainer said in 2024 that he does not sign.

### Cited Findings
- I fetched the first 1024 bytes of `https://dl.static-php.dev/v3/spc-bin/nightly/spc-windows-x64.exe` with an HTTP Range request and parsed the PE32+ optional header (magic `0x20b`). The Certificate Table data directory (index 4) is **offset 0, size 0**, so no Authenticode signature is embedded. [file](https://dl.static-php.dev/v3/spc-bin/nightly/spc-windows-x64.exe)
- No `signtool`, Azure Trusted Signing or other code-signing step exists in `build-windows-x86_64.yml`, `release-build.yml` or the hosted `v3-php-bin-windows.yml`. [main workflows](https://github.com/crazywhalecc/static-php-cli/tree/v3/.github/workflows), [hosted workflows](https://github.com/static-php/static-php-cli-hosted/tree/HEAD/.github/workflows)
- Issue #419 "Windows Defender SmartScreen" (2024-04-24, closed) asked about signing.
  - The owner (crazywhalecc, 2024-04-25) replied: "Unfortunately I know nothing about windows executable signing."
  - He also questioned whether signing a third-party-compiled `php.exe` would be appropriate under its licenses.
  - The issue was closed 2025-02-08 with no signing introduced.
  - [issue #419](https://github.com/crazywhalecc/static-php-cli/issues/419)

### Inferences
- The `php.exe` files in `windows/spc-*` and `v3/php-bin/spc-*` zips are almost certainly unsigned, given no signing step and the maintainer's stated position. This is inferred, not observed.

### Gaps
- `php.exe` inside the zips was not inspected. It is compressed inside the archive, so a header-only range read was not possible without downloading.
- The macOS binaries' code-signing or notarization status was not checked. The release workflow runs `xattr -cr ./spc`, which strips attributes and does not sign.

## Is the download host HTTPS-only, and is there a documented verification procedure?

### Takeaway
- HTTP redirects to HTTPS. The final storage origin sends HSTS with preload.
- **No user-facing verification procedure is documented** in the docs or the READMEs I checked.

### Cited Findings
- `http://dl.static-php.dev/static-php-cli/` returns `301 Moved Permanently` with `Location: https://dl.static-php.dev/static-php-cli/`. The front end is Cloudflare (`Server: cloudflare`). [host](http://dl.static-php.dev/static-php-cli/)
- The final object host `static-php-cli.fra1.digitaloceanspaces.com` returns `strict-transport-security: max-age=15552000; includeSubDomains; preload`. I did not see an HSTS header on the dl.static-php.dev 200/302 responses in the headers I captured. [object](https://static-php-cli.fra1.digitaloceanspaces.com/static-php-cli/common/php-8.5.8-cli-linux-x86_64.tar.gz)
- A GitHub code search of the repo (default branch v3, including `docs/`) found these hits:
  - `attestation`: only `release-build.yml`.
  - `checksum`: only `docs/en/develop/system-build-tools.md` and source files about verifying *inputs* (e.g. `src/StaticPHP/Artifact/Downloader/Type/PhpRelease.php`).
  - `sha256sum`: only the Windows workflow cache key.
  - No guide page tells users how to verify downloaded PHP binaries. [repo](https://github.com/crazywhalecc/static-php-cli)
- The legacy and v3 `README.txt` files in the PHP binary directories document only extensions and build commands. The nightly spc README explicitly disclaims hash verification. [v3 common README](https://dl.static-php.dev/v3/php-bin/common/README.txt), [nightly README](https://dl.static-php.dev/v3/spc-bin/nightly/README.txt)

### Inferences
- The new `.sha256` sidecars work with `sha256sum -c <file>.sha256` run from the archive's directory, but this is undocumented. The workflow comment is the only place it is described.

### Gaps
- I did not crawl every page on static-php.dev. My docs check was a GitHub code search over the repo's `docs/` sources, plus confirming that https://static-php.dev/en/guide/ loads (200). GitHub code search indexes only the default branch.

## Issues / discussions requesting checksums or signatures, and maintainer responses

### Takeaway
- Maintainers have acknowledged the requests.
- Checksums for PHP binaries are rolling out as part of "v3", and they now exist in the v3 tree.
- Signatures have been "suggested" but not implemented.
- An SBOM is promised but not observed.

### Cited Findings
- **#1245 "Publish checksums beside the prebuilt binaries on dl.static-php.dev"** (open, opened 2026-09-28 by svandragt):
  - It asks for a per-directory `SHA256SUMS` or per-archive `.sha256` file.
  - The owner replied on 2026-10-16 that this "will be part of the v3 initiative". He said all binaries will be rebuilt on v3, "introducing features such as hash verification for SPC, PHP, and dependencies, as well as the inclusion of an SBOM".
  - The hosted repo's checksum commit followed on 2026-10-23.
  - [issue #1245](https://github.com/crazywhalecc/static-php-cli/issues/1245)
- **#958 "Add hash verification for SPC and dependencies"** (open, opened 2025-11-04 by the owner):
  - The body reads: "Signature is also suggested."
  - The discussion is about verifying *build inputs* (php-src and `ghrel` sources). The owner noted that "verified" can mean checksum or signature.
  - [issue #958](https://github.com/crazywhalecc/static-php-cli/issues/958)
- **#959 "[RFC] 3.0 Updates - Package And Artifact Changes"** (open) is the v3 RFC referenced by both issues. Its body was not read in detail. [issue #959](https://github.com/crazywhalecc/static-php-cli/issues/959)
- **#419 "Windows Defender SmartScreen"** (closed) is the code-signing discussion covered above. [issue #419](https://github.com/crazywhalecc/static-php-cli/issues/419)
- Searches for `"sha256 binaries"` returned nothing. `"signature"` returned only #958, #959 and #419. [issue search](https://github.com/crazywhalecc/static-php-cli/issues?q=signature)

### Inferences
- #1245 is still open although sidecars now exist in `/v3/`. The likely reason is that the legacy `/static-php-cli/` tree, which most existing tools still point at, has no checksums.

### Gaps
- GitHub Discussions were not searched separately. `gh search issues` covers issues and PRs only.
- I did not observe an SBOM file in any v3 directory listing.
