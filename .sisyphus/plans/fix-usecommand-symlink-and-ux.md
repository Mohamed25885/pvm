# Fix: UseCommand UX and Symlink Bug

## Status
To Do

## Context
Two issues discovered in `lib/src/commands/use_command.dart`:

1. **Symlink Bug**: `GitIgnoreService.ensurePvmSymlinkExists` is called with `targetPath: _osManager.phpVersionsPath` (the `versions/` directory), which would create `.pvm` pointing to the wrong target (the parent directory instead of the specific version). This call is unnecessary because `_applyVersion` already handles symlink creation correctly. In real usage, this would cause "file already exists" errors.

2. **Poor UX**: When `pvm use` is invoked with no version argument and no `.php-version` file exists, the current error is terse and unhelpful. It should list available versions and prompt the user to pick one (interactive) or exit with helpful error (non-interactive).

## Proposed Changes

### File: `lib/src/commands/use_command.dart`

**Change 1: Remove the `ensurePvmSymlinkExists` call**

Replace lines 49-54:
```dart
    // -- Run GitIgnoreService on every use --
    await _gitIgnoreService.ensureGitignoreIncludesPvm(rootPath: rootPath);
    await _gitIgnoreService.ensurePvmSymlinkExists(
      symlinkPath: '$rootPath\\.pvm',
      targetPath: _osManager.phpVersionsPath,
    );
```

With:
```dart
    // -- Run GitIgnoreService on every use --
    await _gitIgnoreService.ensureGitignoreIncludesPvm(rootPath: rootPath);
```

Rationale: `_applyVersion` (called later) is solely responsible for creating the `.pvm` symlink pointing to the correct version directory. `GitIgnoreService` should only manage `.gitignore` entries.

**Change 2: Improve no-version error handling**

Replace lines 57-65 (the no-argument block):
```dart
    if (requestedVersion == null) {
      final lastVersion =
          await _phpVersionManager.readLastUsedVersion(rootPath: rootPath);
      if (lastVersion == null) {
        print('Error: No version specified and no .php-version file found.');
        print('Usage: pvm use <version>');
        return 1;
      }
      return _applyVersion(rootPath, lastVersion, updateFile: true);
    }
```

With:
```dart
    if (requestedVersion == null) {
      final lastVersion =
          await _phpVersionManager.readLastUsedVersion(rootPath: rootPath);
      if (lastVersion == null) {
        // No .php-version: list available versions and prompt user to pick
        final available = _osManager.getAvailableVersions(_osManager.phpVersionsPath);
        if (available.isEmpty) {
          print('Error: No PHP versions found in ${_osManager.phpVersionsPath}');
          return 1;
        }

        print('No .php-version file found. Available versions:');
        for (final v in available) {
          print('  - $v');
        }

        final isInteractive = stdout.hasTerminal;
        if (isInteractive) {
          final picked = await _phpVersionManager.promptVersionPick(
            availableVersions: available,
          );
          if (picked == null) {
            print('Cancelled.');
            return 1;
          }
          return _applyVersion(rootPath, picked, updateFile: true);
        } else {
          print('Error: No .php-version file and non-interactive mode. Specify a version explicitly.');
          return 1;
        }
      }
      return _applyVersion(rootPath, lastVersion, updateFile: true);
    }
```

Rationale: More helpful UX. In interactive mode, allows user to pick from available versions. In non-interactive mode, provides clear error and exit code 1.

## Testing

- Existing tests should continue to pass (the `use_command_test.dart` covers many scenarios). The removal of `ensurePvmSymlinkExists` should not break tests because the mock implementation likely tolerates it; we'll verify.
- The new behavior when no `.php-version` exists and no version is provided requires test updates:
  - `test/commands/use_command_test.dart` already has a test: "UseCommand - no-arg behavior returns error when no version and no .php-version exists". That test expects exit code 1 and error message. We'll need to update its expected output to match the new messages and possibly check that available versions are listed.
  - We may also want to add a test for interactive picker in this scenario.

## Acceptance Criteria

- [ ] `dart analyze` clean
- [ ] All existing tests pass (128+)
- [ ] Updated `use_command_test.dart` to match new error output
- [ ] Manual QA: run `pvm use` with no `.php-version` in interactive mode → sees version list and can pick
- [ ] Manual QA: run `pvm use` non-interactive with no `.php-version` → prints error and exits 1
- [ ] Verify that `.pvm` symlink is created correctly by `_applyVersion` (pointing to `versions/<version>`)

## Commits

- Commit message: `fix(use): remove redundant symlink creation; improve UX when no .php-version`
- Files: `lib/src/commands/use_command.dart`, `test/commands/use_command_test.dart`

## Execution

Once this plan is approved, execute with `/start-work`.
