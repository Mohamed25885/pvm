# Verification Plan: php-version-gitignore Feature Set

## Status
To Do

## Description
Formal verification of the GitIgnoreService + PhpVersionManager + UseCommand + PhpCommand rootPath feature set. All tests passing (128/128) and `dart analyze` clean; this plan documents manual QA, build validation, and integration testing to ensure end-to-end functionality.

## Phases

### Phase F1: Build Validation
- Status: To Do
- Description: Compile the PVM executable and verify it builds without errors.
- Steps:
  1. Run `dart compile exe pvm.dart -o builds/pvm.exe`
  2. Verify `builds/pvm.exe` exists and has reasonable file size (>0 bytes)
- Success Criteria: Build exits with code 0; executable file created.
- QA: Show build output and file listing.

### Phase F2: Test Suite Validation
- Status: Done (from context: 128/128 tests passing)
- Description: Confirm all automated tests pass, including new feature tests.
- Steps:
  1. Run `dart test`
  2. Count passed/failed tests
- Success Criteria: All 128 tests pass.
- QA: Capture test output showing "128 passing" or similar.

### Phase F3: Manual Integration QA
- Status: To Do
- Description: Real-world end-to-end testing of `pvm use`, `.php-version`, `.gitignore` updates, and `pvm php` proxy in a temporary project.
- Steps:
  1. Create a temp directory as a mock project
  2. Ensure `versions/` structure exists with a mock PHP executable (or actual)
  3. Run `pvm use <version>` from project root
  4. Verify:
     - `.php-version` file created with correct JSON version
     - `.pvm` symlink created pointing to the version directory
     - `.gitignore` contains `.pvm/` entry
  5. Run `pvm php --version` and verify it uses the local version (not global)
  6. Test mismatch prompt (interactive) and non-interactive auto-apply
- Success Criteria: All files in expected state; `pvm php` runs with correct working directory and version.
- QA: Show command outputs, file contents, and symlink targets.

### Phase F4: Non-Interactive CI Simulation
- Status: To Do
- Description: Verify `--non-interactive` flag behavior: auto-apply mismatches without updating `.php-version`, and handle missing version with exit code 1.
- Steps:
  1. In temp project with `.php-version` set to 8.0, run `pvm use 8.2 --non-interactive`
  2. Verify:
     - Command exits with code 0
     - `.php-version` unchanged (still 8.0)
     - `.pvm` symlink now points to 8.2
  3. Run `pvm use nonexistent --non-interactive`
  4. Verify exit code 1 and appropriate error message
- Success Criteria: Non-interactive behavior matches specification.
- QA: Show command outputs and file states.

### Phase F5: Build Executable Distribution Test
- Status: To Do
- Description: After compiling, test the standalone executable to ensure it functions as a real CLI tool.
- Steps:
  1. Copy `builds/pvm.exe` to a separate directory (simulate user install)
  2. Create a `versions/` directory alongside it with mock PHP executables
  3. Run `pvm.exe global <version>` and verify global symlink
  4. Run `pvm.exe list` to see versions
  5. Run `pvm.exe use <version>` in a project directory
  6. Run `pvm.exe php --version` and confirm local version is used
- Success Criteria: Executable runs independently; all commands work as expected.
- QA: Show outputs of each command; verify file system changes.

## Execution Strategy
- Phase F1: `category="quick"`, run `dart compile exe`
- Phase F2: Already done, but re-run for evidence capture
- Phase F3: Manual QA using `bash` tool; delegate to `unspecified-high` for comprehensive test script creation, then execute manually
- Phase F4: Manual QA with `bash`; capture exit codes using `echo %errorlevel%`
- Phase F5: Manual QA with `bash`; test standalone executable

## Dependencies
- F3 depends on F1 (executable needed for integration tests)
- F4 depends on F3 (same environment)
- F5 depends on F1 (build)

## Evidence Requirements
- Build output (stdout/stderr)
- Test output with counts
- Command outputs (screenshots or text)
- File listings (`dir` or `ls`) showing `.php-version`, `.pvm`, `.gitignore`
- Symlink targets (`dir` or `ls -l`)
- Exit codes (for non-interactive tests)

## Notes
- All tests already passing, but F2 re-run is for evidence capture in this session.
- Manual QA must be performed by the agent (per ultrawork-mode mandate), using the Bash tool to execute actual commands and capture output.
