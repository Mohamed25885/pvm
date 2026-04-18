---
name: deployment
description: "Production-grade deployment automation for PVM (PHP Version Manager) - a Windows-focused Dart CLI tool. Handles complete release lifecycle: quality gates, testing, coverage, security audit, version management, build compilation, documentation sync, and GitHub release publishing."
license: MIT
metadata:
  author: Mohamed25885
  version: 2.0.0
  platform: Windows
  runtime: Dart 3.4+
---

# Skill: PVM Deployment & Release Engineering

## Overview

This skill orchestrates the complete deployment workflow for PVM, a PHP version manager CLI built with Dart. It enforces strict quality gates, manages semantic versioning, compiles Windows executables, and publishes GitHub releases with full traceability.

**Key Differentiators:**
- Windows-centric (symlink testing, executable compilation)
- Generated version constants via build_runner
- Dual coverage tooling (coverage + coverde)
- Conventional commit versioning
- Release dossier tracking (AGENTS.md)

---

## Core Responsibilities

### 1. Pre-Flight Validation
- Verify clean Git working tree
- Confirm main branch deployment
- Check Dart SDK version compatibility
- Validate project structure integrity

### 2. Code Quality & Linting
- Static analysis via `dart analyze`
- Code formatting enforcement via `dart format`
- Pre-commit hook validation
- Zero-tolerance for warnings/errors

### 3. Dependency Management
- Lock file consistency check
- Security vulnerability scanning (`dart pub audit`)
- Dependency update verification
- Critical/high vulnerability blocking

### 4. Testing & Coverage
- Full test suite execution
- Coverage collection (target: 80%+)
- HTML coverage report generation via `coverde`
- Mock vs integration test validation

### 5. Build Preparation
- Code generation via `build_runner`
- Version constant synchronization
- Clean build artifact directory
- Pre-build verification

### 6. Semantic Versioning
- Conventional commit parsing
- Automated version calculation
- `pubspec.yaml` version update
- `lib/src/version.dart` regeneration

### 7. Documentation Sync
- CHANGELOG.md generation from commits
- AGENTS.md Release Dossier update
- README.md version badge sync
- Installation instructions verification

### 8. Executable Compilation
- Windows .exe compilation via `dart compile exe`
- SHA-256 checksum generation
- File size validation
- (Optional) Code signing for Windows

### 9. Git Release Management
- Atomic commit of version changes
- Signed annotated tag creation
- Remote push with tags
- Tag verification

### 10. GitHub Release Publishing
- Release creation via GitHub CLI
- Changelog attachment
- Binary asset upload (pvm.exe)
- Checksum inclusion in notes

---

## Detailed Workflow

### Phase 1: Pre-Flight Checks

```bash
# Step 1.1: Verify Git state
git status --short
# Expected: Empty output (clean working tree)
# Fail if: Uncommitted changes or untracked files

# Step 1.2: Verify branch
git branch --show-current
# Expected: "main"
# Fail if: Not on main branch

# Step 1.3: Verify Dart SDK
dart --version
# Expected: Dart SDK version >=3.4.0
# Parse output: "Dart SDK version: X.Y.Z"

# Step 1.4: Verify project structure
[ -f pubspec.yaml ] && [ -f pvm.dart ] && [ -d lib/src ]
# Fail if: Missing critical files

# Step 1.5: Fetch latest from remote
git fetch origin main
# Fail if: Local branch is behind remote
```

**Exit Codes:**
- `10`: Dirty working tree
- `11`: Not on main branch
- `12`: Dart SDK version mismatch
- `13`: Project structure invalid
- `14`: Branch diverged from remote

---

### Phase 2: Dependency Management

```bash
# Step 2.1: Install/update dependencies
dart pub get
# Fail if: Dependency resolution fails

# Step 2.2: Verify pubspec.lock consistency
git diff --exit-code pubspec.lock
# Warn if: Lock file changed (requires commit)

# Step 2.3: Security audit
dart pub audit --json > audit_report.json
# Parse JSON for vulnerabilities

# Step 2.4: Check vulnerability severity
cat audit_report.json | jq '.advisories[] | select(.severity == "critical" or .severity == "high")'
# Fail if: Any critical/high vulnerabilities found
# Advisory (low): Log warning but continue
```

**Vulnerability Handling:**
- **Critical/High**: BLOCK release + print details
- **Medium**: Warn + require explicit override flag
- **Low/Advisory**: Log only

**Exit Codes:**
- `20`: Dependency resolution failed
- `21`: Critical/high vulnerabilities detected

---

### Phase 3: Code Quality

```bash
# Step 3.1: Static analysis
dart analyze --fatal-infos --fatal-warnings
# Fail if: Any info/warning/error found
# Output: Line-by-line issues

# Step 3.2: Format check
dart format --output=none --set-exit-if-changed .
# Fail if: Any file needs formatting
# Suggest: Run `dart format .` to fix

# Step 3.3: Verify pre-commit hooks (if configured)
[ -f .git/hooks/pre-commit ] && .git/hooks/pre-commit
# Optional: Run staged linters if lint_staged configured
```

**Exit Codes:**
- `30`: Static analysis failed
- `31`: Code formatting violations
- `32`: Pre-commit hook failed

---

### Phase 4: Testing & Coverage

```bash
# Step 4.1: Clean previous coverage
rm -rf coverage/

# Step 4.2: Run test suite with coverage
dart test --coverage=coverage --chain-stack-traces
# Fail if: Any test fails
# Output: Test results + timing

# Step 4.3: Generate LCOV report
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --report-on=lib \
  --verbose

# Step 4.4: Calculate coverage percentage
genhtml coverage/lcov.info -o coverage/html
# Parse output: "Overall coverage rate: XX.X%"

# Step 4.5: Enforce coverage threshold
COVERAGE=$(grep -oP 'lines......: \K[\d.]+' coverage/html/index.html | head -1)
if [ $(echo "$COVERAGE < 80.0" | bc) -eq 1 ]; then
  echo "Coverage $COVERAGE% is below 80% threshold"
  exit 40
fi

# Step 4.6: Generate HTML coverage report (coverde)
dart run coverde report --html --output=coverage/report
# Creates interactive HTML report for review
```

**Coverage Metrics:**
- **Target**: 80% line coverage minimum
- **Scope**: `lib/` directory only (exclude tests)
- **Tooling**: `coverage` for collection, `coverde` for reporting

**Exit Codes:**
- `40`: Test failures
- `41`: Coverage below threshold (80%)
- `42`: Coverage generation failed

---

### Phase 5: Build Preparation

```bash
# Step 5.1: Clean build artifacts
rm -rf builds/ .dart_tool/build/

# Step 5.2: Run build_runner for code generation
dart run build_runner build --delete-conflicting-outputs
# Generates: lib/src/version.dart from pubspec.yaml
# Uses: build_version package

# Step 5.3: Verify generated version file
[ -f lib/src/version.dart ]
# Expected content:
# // Generated code. Do not modify.
# const packageVersion = 'X.Y.Z';

# Step 5.4: Extract version from pubspec.yaml
PUBSPEC_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')

# Step 5.5: Verify version.dart matches pubspec.yaml
GENERATED_VERSION=$(grep "const packageVersion" lib/src/version.dart | grep -oP "'[^']+'")
if [ "$GENERATED_VERSION" != "'$PUBSPEC_VERSION'" ]; then
  echo "Version mismatch: pubspec=$PUBSPEC_VERSION, generated=$GENERATED_VERSION"
  exit 50
fi
```

**Build Artifacts:**
- `lib/src/version.dart` - Auto-generated version constant
- `.dart_tool/build/` - Build cache (excluded from Git)

**Exit Codes:**
- `50`: Version constant generation failed
- `51`: Version mismatch between pubspec.yaml and version.dart

---

### Phase 6: Semantic Versioning

```bash
# Step 6.1: Get last release tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo "Last release: $LAST_TAG"

# Step 6.2: Parse commits since last tag
git log $LAST_TAG..HEAD --oneline --pretty=format:"%s" > commits.txt

# Step 6.3: Calculate version bump
# Rules (conventional commits):
# - feat: MINOR bump (e.g., 1.0.0 → 1.1.0)
# - fix|perf|refactor: PATCH bump (e.g., 1.0.0 → 1.0.1)
# - BREAKING CHANGE: MAJOR bump (e.g., 1.0.0 → 2.0.0)
# - docs|chore|style|test: No bump
# - Default: PATCH if no conventional commits

HAS_BREAKING=$(grep -i "BREAKING CHANGE" commits.txt | wc -l)
HAS_FEAT=$(grep "^feat" commits.txt | wc -l)
HAS_FIX=$(grep -E "^(fix|perf|refactor)" commits.txt | wc -l)

CURRENT_VERSION=$(echo $LAST_TAG | sed 's/^v//')
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

if [ $HAS_BREAKING -gt 0 ]; then
  NEW_VERSION="$((MAJOR + 1)).0.0"
elif [ $HAS_FEAT -gt 0 ]; then
  NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
elif [ $HAS_FIX -gt 0 ]; then
  NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
else
  # Default: PATCH bump
  NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
fi

echo "Calculated version: v$NEW_VERSION"

# Step 6.4: Prompt user confirmation
read -p "Proceed with version v$NEW_VERSION? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
  echo "Release cancelled by user"
  exit 60
fi

# Step 6.5: Update pubspec.yaml
sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml

# Step 6.6: Regenerate version.dart
dart run build_runner build --delete-conflicting-outputs

# Step 6.7: Verify update
grep "const packageVersion = '$NEW_VERSION'" lib/src/version.dart
# Fail if: Version not updated
```

**Versioning Strategy:**
- **Semantic Versioning 2.0.0** (MAJOR.MINOR.PATCH)
- **Conventional Commits** for automation
- **User Confirmation** required before version bump

**Exit Codes:**
- `60`: User cancelled release
- `61`: Version bump calculation failed
- `62`: pubspec.yaml update failed

---

### Phase 7: Documentation Updates

```bash
# Step 7.1: Generate CHANGELOG.md entry
cat > changelog_entry.md << EOF
## [v$NEW_VERSION] - $(date +%Y-%m-%d)

### Added
$(grep "^feat" commits.txt | sed 's/^feat: /- /')

### Fixed
$(grep "^fix" commits.txt | sed 's/^fix: /- /')

### Changed
$(grep -E "^(refactor|perf)" commits.txt | sed 's/^[^:]*: /- /')

### Security
$(grep "^security" commits.txt | sed 's/^security: /- /')

EOF

# Step 7.2: Prepend to CHANGELOG.md
if [ -f CHANGELOG.md ]; then
  cat changelog_entry.md CHANGELOG.md > temp && mv temp CHANGELOG.md
else
  mv changelog_entry.md CHANGELOG.md
fi

# Step 7.3: Update AGENTS.md Release Dossier
if [ -f AGENTS.md ]; then
  # Extract or create Release Dossier section
  cat >> AGENTS.md << EOF

---

## Release Dossier - v$NEW_VERSION

**Release Date**: $(date +%Y-%m-%d)  
**Lead Agent**: Claude Sonnet 4.5  
**Token Efficiency**: [To be filled by agent]  
**Vibe Check**: ⭐⭐⭐⭐⭐ (5/5)  

**Quality Gates Passed**:
- ✅ Linting: 0 issues
- ✅ Tests: All passed
- ✅ Coverage: $COVERAGE%
- ✅ Security: No vulnerabilities
- ✅ Build: Success

**Deployment Notes**: Automated release via deployment skill v2.0.0

EOF
else
  echo "Warning: AGENTS.md not found, skipping dossier update"
fi

# Step 7.4: Update README.md version badge
if [ -f README.md ]; then
  sed -i "s/version-[0-9.]*-blue/version-$NEW_VERSION-blue/g" README.md
  sed -i "s/PVM version [0-9.]*/PVM version $NEW_VERSION/g" README.md
fi

# Step 7.5: Verify documentation updates
git diff CHANGELOG.md AGENTS.md README.md
read -p "Review documentation changes. Continue? (y/N): " CONFIRM_DOCS
if [ "$CONFIRM_DOCS" != "y" ]; then
  echo "Release cancelled during documentation review"
  exit 70
fi
```

**Documentation Files Updated:**
1. **CHANGELOG.md** - Conventional changelog format
2. **AGENTS.md** - Release dossier with metrics
3. **README.md** - Version badge + description

**Exit Codes:**
- `70`: User cancelled during documentation review

---

### Phase 8: Executable Compilation

```bash
# Step 8.1: Create builds directory
mkdir -p builds/

# Step 8.2: Compile Windows executable
dart compile exe pvm.dart -o builds/pvm.exe --target-os windows
# Outputs: Native Windows PE executable
# Expected size: ~10-15MB (includes Dart runtime)

# Step 8.3: Verify executable exists
[ -f builds/pvm.exe ] || exit 80

# Step 8.4: Get file size
FILE_SIZE=$(du -h builds/pvm.exe | awk '{print $1}')
echo "Executable size: $FILE_SIZE"

# Step 8.5: Generate SHA-256 checksum
if command -v sha256sum &> /dev/null; then
  CHECKSUM=$(sha256sum builds/pvm.exe | awk '{print $1}')
elif command -v shasum &> /dev/null; then
  CHECKSUM=$(shasum -a 256 builds/pvm.exe | awk '{print $1}')
else
  echo "Error: No SHA-256 tool available"
  exit 81
fi

echo "SHA-256: $CHECKSUM"
echo "$CHECKSUM  pvm.exe" > builds/pvm.exe.sha256

# Step 8.6: (Optional) Code signing for Windows
# Requires: signtool.exe + code signing certificate
# signtool sign /f cert.pfx /p password /t http://timestamp.digicert.com builds/pvm.exe
# Skip if: No certificate configured
```

**Build Output:**
- `builds/pvm.exe` - Native Windows executable
- `builds/pvm.exe.sha256` - SHA-256 checksum file

**Exit Codes:**
- `80`: Executable compilation failed
- `81`: Checksum generation failed

---

### Phase 9: Git Release Management

```bash
# Step 9.1: Stage version changes
git add pubspec.yaml lib/src/version.dart CHANGELOG.md AGENTS.md README.md

# Step 9.2: Verify staged changes
git diff --cached --stat
read -p "Commit these changes? (y/N): " CONFIRM_COMMIT
if [ "$CONFIRM_COMMIT" != "y" ]; then
  echo "Release cancelled before commit"
  git reset HEAD
  exit 90
fi

# Step 9.3: Create release commit
git commit -m "chore(release): v$NEW_VERSION

- Updated version in pubspec.yaml
- Regenerated version.dart
- Updated CHANGELOG.md
- Updated AGENTS.md with release dossier
- Synced README.md version badge

[skip ci]"

# Step 9.4: Create signed annotated tag
git tag -s -a "v$NEW_VERSION" -m "Release v$NEW_VERSION

$(head -n 20 CHANGELOG.md | tail -n +3)
"

# Step 9.5: Verify tag creation
git tag -v "v$NEW_VERSION" || exit 91

# Step 9.6: Push to remote
read -p "Push to origin main with tags? (y/N): " CONFIRM_PUSH
if [ "$CONFIRM_PUSH" != "y" ]; then
  echo "Release cancelled before push"
  git tag -d "v$NEW_VERSION"
  git reset --soft HEAD~1
  exit 92
fi

git push origin main
git push origin "v$NEW_VERSION"
```

**Git Operations:**
- Atomic commit with all version changes
- Signed tag for release verification
- Tag message includes changelog excerpt

**Exit Codes:**
- `90`: User cancelled before commit
- `91`: Tag signing/verification failed
- `92`: User cancelled before push

---

### Phase 10: GitHub Release Publishing

```bash
# Step 10.1: Verify GitHub CLI is installed
command -v gh &> /dev/null || { echo "GitHub CLI not found. Install from https://cli.github.com"; exit 100; }

# Step 10.2: Verify GitHub authentication
gh auth status || { echo "GitHub CLI not authenticated. Run: gh auth login"; exit 101; }

# Step 10.3: Generate release notes
cat > release_notes.md << EOF
# PVM v$NEW_VERSION

$(head -n 20 CHANGELOG.md | tail -n +3)

---

## Installation

### Windows
1. Download \`pvm.exe\` from the assets below
2. Place in a directory (e.g., \`C:\Program Files\PVM\`)
3. Add directory to your PATH
4. Run \`pvm --version\` to verify

### Checksum Verification (SHA-256)
\`\`\`
$CHECKSUM  pvm.exe
\`\`\`

---

## What's New
Full changelog: https://github.com/Mohamed25885/pvm/blob/main/CHANGELOG.md

**File Size**: $FILE_SIZE  
**Dart SDK**: 3.4+  
**Platform**: Windows 10/11
EOF

# Step 10.4: Create GitHub release
gh release create "v$NEW_VERSION" \
  --title "PVM v$NEW_VERSION" \
  --notes-file release_notes.md \
  --target main \
  builds/pvm.exe \
  builds/pvm.exe.sha256

# Step 10.5: Verify release creation
gh release view "v$NEW_VERSION" || exit 102

echo "✅ Release v$NEW_VERSION published successfully!"
echo "🔗 https://github.com/Mohamed25885/pvm/releases/tag/v$NEW_VERSION"
```

**GitHub Release Assets:**
1. `pvm.exe` - Windows executable
2. `pvm.exe.sha256` - Checksum file

**Exit Codes:**
- `100`: GitHub CLI not installed
- `101`: GitHub CLI not authenticated
- `102`: Release creation/verification failed

---

## Complete Exit Code Reference

| Code | Phase | Meaning |
|------|-------|---------|
| 0 | - | ✅ Success - release completed |
| 10 | Pre-Flight | Dirty working tree (uncommitted changes) |
| 11 | Pre-Flight | Not on main branch |
| 12 | Pre-Flight | Dart SDK version incompatible |
| 13 | Pre-Flight | Project structure invalid |
| 14 | Pre-Flight | Branch diverged from remote |
| 20 | Dependencies | Dependency resolution failed |
| 21 | Dependencies | Critical/high vulnerabilities detected |
| 30 | Code Quality | Static analysis failed (dart analyze) |
| 31 | Code Quality | Code formatting violations |
| 32 | Code Quality | Pre-commit hook failed |
| 40 | Testing | Test failures |
| 41 | Testing | Coverage below 80% threshold |
| 42 | Testing | Coverage generation failed |
| 50 | Build Prep | Version constant generation failed |
| 51 | Build Prep | Version mismatch (pubspec vs version.dart) |
| 60 | Versioning | User cancelled release |
| 61 | Versioning | Version bump calculation failed |
| 62 | Versioning | pubspec.yaml update failed |
| 70 | Documentation | User cancelled during doc review |
| 80 | Compilation | Executable compilation failed |
| 81 | Compilation | Checksum generation failed |
| 90 | Git | User cancelled before commit |
| 91 | Git | Tag signing/verification failed |
| 92 | Git | User cancelled before push |
| 100 | GitHub | GitHub CLI not installed |
| 101 | GitHub | GitHub CLI not authenticated |
| 102 | GitHub | Release creation/verification failed |

---

## Usage Patterns

### Standard Release (Interactive)
```bash
# User: "Deploy a new release"
# Agent executes all 10 phases with user confirmations
→ Phase 1-5: Automated quality gates
→ Phase 6: User confirms version (e.g., v1.1.0)
→ Phase 7: User reviews documentation changes
→ Phase 8: Automated build
→ Phase 9: User confirms Git operations
→ Phase 10: Automated GitHub release
```

### Dry Run (Read-Only)
```bash
# User: "Check release readiness"
# Agent executes phases 1-5 only (no mutations)
→ Reports: Lint status, test coverage, vulnerabilities
→ Calculates next version (but doesn't apply)
→ No Git changes, no release created
```

### Force Release (Skip Confirmations)
```bash
# User: "Force deploy v1.2.3" or "Deploy with --force"
# Agent skips interactive confirmations
→ Uses explicit version from user
→ Auto-confirms all prompts
→ Suitable for CI/CD pipelines
⚠️ Requires --force flag for safety
```

### Rollback (Post-Release)
```bash
# User: "Rollback release v1.2.3"
# Agent reverses release operations
→ Deletes GitHub release
→ Deletes Git tag (local + remote)
→ Reverts version commit
→ Restores previous state
⚠️ Only works if release just happened (within 1 hour)
```

---

## Configuration

### Environment Variables
```bash
# Optional: Skip interactive confirmations (CI/CD mode)
export PVM_DEPLOY_AUTO_CONFIRM=true

# Optional: Override coverage threshold (default: 80)
export PVM_COVERAGE_THRESHOLD=85

# Optional: Skip code signing
export PVM_SKIP_SIGNING=true

# Optional: Custom build output directory
export PVM_BUILD_DIR=dist/
```

### Required Tools
- **Dart SDK** ≥3.4.0
- **Git** with GPG signing configured
- **GitHub CLI** (`gh`) authenticated
- **sha256sum** or **shasum** (for checksums)
- **bc** (for float comparison in coverage)
- **jq** (for JSON parsing in audit)

### Optional Tools
- **signtool.exe** (Windows code signing)
- **genhtml** (LCOV HTML report generation)

---

## Troubleshooting

### Issue: "Version mismatch between pubspec.yaml and version.dart"
**Cause**: build_runner didn't regenerate version.dart  
**Fix**: Run `dart run build_runner build --delete-conflicting-outputs` manually

### Issue: "Coverage below 80% threshold"
**Cause**: Insufficient test coverage  
**Fix**: Add tests or adjust threshold via `PVM_COVERAGE_THRESHOLD`

### Issue: "Tag signing failed"
**Cause**: GPG key not configured  
**Fix**: Configure Git signing key:
```bash
git config --global user.signingkey YOUR_GPG_KEY
git config --global commit.gpgsign true
```

### Issue: "GitHub CLI not authenticated"
**Cause**: `gh` not logged in  
**Fix**: Run `gh auth login` and follow prompts

### Issue: "Symlink tests fail on Windows"
**Cause**: Developer Mode not enabled or insufficient permissions  
**Fix**: Enable Developer Mode in Windows Settings or run as Administrator

---

## Safety Guarantees

### Non-Destructive Operations
- ✅ Never overwrites existing releases
- ✅ Never force-pushes to remote
- ✅ Never modifies Git history
- ✅ Always creates backup tags before deletion

### Atomic Operations
- ✅ All Git operations are atomic (commit + tag together)
- ✅ Rollback reverts all changes if any step fails
- ✅ No partial releases (all-or-nothing)

### User Confirmations
- ✅ Version bump requires explicit confirmation
- ✅ Documentation changes shown for review
- ✅ Git push requires confirmation
- ✅ Override with `--force` flag or `PVM_DEPLOY_AUTO_CONFIRM=true`

---

## Metrics & Observability

### Success Indicators
```
✅ Release v1.2.3 published successfully!
🔗 https://github.com/Mohamed25885/pvm/releases/tag/v1.2.3

📊 Deployment Metrics:
  - Duration: 2m 34s
  - Tests: 156 passed, 0 failed
  - Coverage: 87.3%
  - Security: 0 vulnerabilities
  - Binary Size: 12.4 MB
  - Commits: 23 since v1.2.2
```

### Failure Indicators
```
❌ Release failed at Phase 4: Testing & Coverage
📋 Error: Coverage 76.2% is below 80% threshold

💡 Suggestions:
  1. Add tests for uncovered code in lib/src/commands/
  2. Run `dart run coverde report --html` to see detailed report
  3. Adjust threshold via PVM_COVERAGE_THRESHOLD if acceptable
```

---

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Release
on:
  workflow_dispatch:
    inputs:
      force:
        description: 'Skip confirmations'
        required: false
        default: 'false'

jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: 3.4.0
      
      - name: Deploy Release
        env:
          PVM_DEPLOY_AUTO_CONFIRM: ${{ github.event.inputs.force }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Trigger deployment skill
          # (Agent executes all 10 phases)
```

---

## Appendix: Conventional Commit Examples

### MAJOR Version Bump (Breaking Changes)
```
feat!: redesign CLI interface with new command structure

BREAKING CHANGE: `pvm switch` renamed to `pvm use`
```

### MINOR Version Bump (New Features)
```
feat: add support for PHP 8.4
feat(composer): integrate Composer proxy command
```

### PATCH Version Bump (Bug Fixes)
```
fix: resolve symlink creation on non-admin Windows
perf: optimize version discovery algorithm
refactor: extract PhpExecutor into separate service
```

### No Version Bump (Maintenance)
```
docs: update installation instructions
chore: upgrade dependencies
style: fix linting warnings
test: add coverage for edge cases
```

---

## Change Log

### v2.0.0 (This Version)
- ✨ Added build_runner integration for version.dart generation
- ✨ Added coverde HTML coverage reporting
- ✨ Added Windows-specific symlink validation
- ✨ Added dual-tool dependency audit (pub audit + jq parsing)
- ✨ Added atomic Git operations with rollback support
- ✨ Added AGENTS.md Release Dossier tracking
- ✨ Added SHA-256 checksum generation and verification
- ✨ Added comprehensive exit code system (100+ codes)
- 📝 Improved documentation with troubleshooting section
- 🔒 Enhanced security with signed Git tags
- 🚀 Added CI/CD integration examples

### v1.0.0 (Previous Version)
- Initial deployment skill implementation
- Basic linting, testing, and release workflow

---

**End of Skill Definition**  