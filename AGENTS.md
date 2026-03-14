# AGENTS.md

This document provides essential information for agentic coding agents working in the PVM (PHP Version Manager) repository.

## Project Overview

PVM is a Dart-based command-line tool designed to manage multiple PHP versions on Windows. It allows users to switch between global and local PHP versions by creating symbolic links and provides a proxy to run PHP commands through the selected version.

## Using .agents Directory

**IMPORTANT**: Before acting on ANY task, agents MUST read and use the `.agents` directory.

The `.agents` directory contains all resources for agentic coding:
- **plans/** - Plan documents for features and refactoring
- **skills/** - Specialized skills for specific tasks
- **commands/** - Reusable command templates
- **templates/** - Code templates
- **memories/** - Past interactions and learnings
- **docs/** - Documentation and guidelines

### Agent Workflow

1. **First**: Read `.agents/README.md` for overview
2. **Then**: Check `.agents/plans/` for existing plans
3. **Then**: Look at `.agents/docs/` for relevant guidelines
4. **Then**: Use `.agents/skills/` for specialized workflows
5. **Then**: Reference `.agents/templates/` for code patterns
6. **Then**: Check `.agents/memories/` for project context

---

## Environment & Dependencies

- **Language:** Dart (SDK ^3.4.0)
- **Target Platform:** Windows (strictly uses Windows-specific APIs and path conventions)
- **Key Dependencies:**
  - `args`: Command-line argument parsing (CommandRunner).
  - `ffi` & `win32`: Interaction with Windows APIs (e.g., for process management).
  - `path`: Path manipulation.
  - `test` & `mocktail`: Testing framework and mocking.

## Architecture

### OS Abstraction Layer
The project uses a Hardware Abstraction Layer (HAL) to separate Windows-specific logic from business logic. This enables testing on WSL/Linux.

- **`interfaces/os_manager.dart`**: Defines `IOSManager` and `IProcessManager` interfaces.
- **`utils/windows_os_manager.dart`**: Windows implementation using `dart:io` and `win32`.
- **`utils/mock_os_manager.dart`**: Mock implementation for testing on non-Windows platforms.
- **`utils/job_object_manager.dart`**: Handles process lifecycle and cleanup.

### CommandRunner Pattern
The CLI uses `package:args`'s `CommandRunner` for modular command handling:
- `GlobalCommand`: Sets system-wide PHP version.
- `UseCommand`: Sets project-local PHP version.
- `ListCommand`: Lists available PHP versions.
- `PhpCommand`: Runs PHP with local configuration using `ProcessStartMode.inheritStdio`.

## Critical Commands

### Development & Maintenance
- **Analyze Code:** `dart analyze`
- **Format Code:** `dart format .`
- **Fix Lints:** `dart fix --apply`

### Execution
- **Run locally:** `dart pvm.dart <command> [arguments]`
- **Run PHP proxy:** `dart pvm.dart php [arguments]`

### Build
- **Compile Executable:** `dart compile exe pvm.dart -o builds/pvm.exe`

### Testing
- **Run all tests:** `dart test`
- **Run single test:** `dart test test/path_to_test.dart`

## Code Style & Guidelines

### 1. Naming Conventions
- **Classes:** `PascalCase` (e.g., `OptionCreator`, `PhpProxy`).
- **Methods & Variables:** `camelCase` (e.g., `createLocal`, `availableVersions`).
- **Enums:** `PascalCase` for the enum name, `camelCase` for values.
- **Files:** `snake_case.dart` (e.g., `php_proxy.dart`).

### 2. Imports
Group imports in the following order, with a blank line between groups:
1. `dart:` imports
2. `package:` imports
3. Relative path imports

Example:
```dart
import 'dart:io';
import 'dart:async';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'utils/utils.dart';
```

### 3. Formatting
- Use `dart format .` to maintain consistent formatting.
- Line length should follow the Dart default (80 characters).

### 4. Types & Safety
- Use `final` for all variables that do not change after initialization.
- Use `late` for variables initialized after the constructor but before use.
- Prefer explicit return types for all public methods and static functions.
- Leverage Dart's Record types for multiple return values (e.g., `({String from, String to})`).

### 5. Error Handling
- Wrap file system and process operations in `try-catch` blocks.
- On fatal errors in `main()`, set `exitCode = 1` and print the error message.
- Use `throw Exception("Message")` for internal errors that should be caught by callers.

### 6. Path Handling
- This project specifically targets Windows.
- While `package:path` is available, existing code often uses string interpolation with backslashes: `"${Utils.programDirectory.path}\\versions"`.
- When adding new code, prefer `p.join()` for better portability, but maintain consistency with neighboring code if modifying existing logic.

### 7. Testing Guidelines
- **Always test on WSL first**: Use the `MockOSManager` to verify logic without needing Windows.
- **Test edge cases**: Invalid paths, missing versions, symlink failures.
- **Regression tests**: When adding new commands, add tests to `test/mock_test.dart`.

## Project Structure

- `pvm.dart`: The entry point. Uses `CommandRunner` for command dispatching.
- `interfaces/`: Contains `os_manager.dart` defining OS abstractions.
- `enums/`: Contains `Options` enum (legacy, may be removed in future).
- `utils/`:
  - `windows_os_manager.dart`: Windows-specific implementation.
  - `mock_os_manager.dart`: Mock implementation for testing.
  - `job_object_manager.dart`: Process lifecycle management.
  - `php_proxy.dart`: Legacy proxy (being phased out).
  - `symlink_creator.dart`: Legacy symlink logic (being phased out).
  - `gitngore.dart`: Helper to update `.gitignore` files.
- `test/`: Test files (e.g., `mock_test.dart`).
- `versions/`: (Ignored in git) Contains PHP version subdirectories.
- `builds/`: Destination for compiled executables.

## Implementation Details to Remember

### PHP Proxy (PhpCommand)
- Uses `ProcessStartMode.inheritStdio` for high-performance, low-latency piping.
- Ideal for long-running processes like `php artisan serve`.
- Correctly handles interactive prompts and terminal colors.

### Symlinks
- Creating local/global versions relies on Windows symbolic links.
- Requires either **Developer Mode** enabled or running as **Administrator**.
- The `createSymLink` method in `IOSManager` handles the `mklink` command.

### Local Config
- Local versions are managed via a `.pvm` directory in the current working directory.
- Global versions are stored in `%USERPROFILE%\.pvm`.

## Common Pitfalls

1. **Developer Mode**: If symlink creation fails, check if Developer Mode is enabled in Windows Settings.
2. **WSL Testing**: On WSL, always use `MockOSManager` - never try to run Windows-specific code.
3. **Path Separators**: Always use `\\` for Windows paths; do not rely on `dart:io` to normalize them automatically in all contexts.

## Rule Integration

Follow standard Dart `lints` package recommendations as configured in `pubspec.yaml`.

## Plan Persistence

When working on significant features or refactoring, create a plan document to track progress:

### Plan Location
- Store plans in `.agents/plans/[plan-title].md`

### Plan Structure
```markdown
# [Plan Title]

## Status
[To Do / Doing / Done]

## Description
2-3 sentence summary of the plan

## Phases
### Phase 1: [Title]
- Status: [To Do / Doing / Done]
- Description: What this phase does
- Steps:
  1. [Step]
  2. [Step]

### Phase 2: [Title]
...

## Conclusion
What was achieved

## Suggestions
Future improvements
```

### Guidelines
1. **Create early**: Create the plan before starting significant work
2. **Track progress**: ALWAYS update phase status after starting each phase
   - Mark as "Doing" when work begins on a phase
   - Mark as "Done" when phase is completed
3. **Keep updated**: Update status as phases are completed
4. **Reference**: Use plan as guide but adapt as needed
5. **Persist**: Always save the plan to `.agents/plans/` before proceeding with implementation
