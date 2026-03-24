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

- **`lib/src/core/os_manager.dart`**: Defines `IOSManager` (filesystem, environment, directory operations) and `IProcessManager` (process execution) interfaces.
- **`lib/src/managers/windows_os_manager.dart`**: Windows implementation using `dart:io` and `win32`. Provides `currentEnvironment` getter for PATH access.
- **`lib/src/managers/mock_os_manager.dart`**: Mock implementation for testing on non-Windows platforms. Includes configurable `environment` map for simulating PATH and other environment variables.

### Process Management
- **`lib/src/core/process_manager.dart`**: Defines `ProcessSpec` (executable, arguments, workingDirectory, environment) and `IProcessManager` interface with `runInteractive` and `runCaptured`.
- **`lib/src/process/io_process_manager.dart`**: Cross-platform implementation using `Process.start` with `ProcessStartMode.normal` and manual streaming of stdin/stdout/stderr. This approach avoids Dart SDK issues with process hanging on exit.

### Service Layer
- **`lib/src/services/php_executor.dart`**: Encapsulates PHP execution logic. Provides `runPhp()` for direct PHP invocation and `runScript()` for running PHP scripts (e.g., Composer). Resolves PHP executable from `.pvm` symlink and uses `IProcessManager` for actual execution. This service is used by both `PhpCommand` and `ComposerCommand`.

### CommandRunner Pattern
The CLI uses `package:args`'s `CommandRunner` for modular command handling:
- `GlobalCommand`: Sets system-wide PHP version.
- `UseCommand`: Sets project-local PHP version.
- `ListCommand`: Lists available PHP versions.
- `PhpCommand`: Runs PHP using local version via `PhpExecutor`.
- `ComposerCommand`: Runs Composer using local PHP and PATH lookup.

## Critical Commands

### Development & Maintenance
- **Analyze Code:** `dart analyze`
- **Format Code:** `dart format .`
- **Fix Lints:** `dart fix --apply`

### Execution
- **Run locally:** `dart pvm.dart <command> [arguments]`
- **Run PHP proxy:** `dart pvm.dart php [arguments]`
- **Run Composer proxy:** `dart pvm.dart composer [arguments]`

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
- **Always use `package:path` (`p.join()`)** for building paths. Avoid hardcoded backslashes or forward slashes. The `path` package handles separators correctly on all platforms and reduces bugs.
  - ✅ Good: `p.join(rootPath, '.pvm', 'php.exe')`
  - ❌ Avoid: `'$rootPath\\.pvm\\php.exe'` (platform-dependent string interpolation)
- Even on Windows, `p.join()` produces correct backslashes and normalizes paths.
- When modifying existing code that uses hardcoded separators, refactor to use `p.join()` for consistency and maintainability.

### 7. Environment Access
- The `IOSManager` interface includes a `currentEnvironment` getter that returns `Map<String, String>`. This is used for PATH lookup (e.g., in `ComposerCommand`) and should be preferred over `Platform.environment` directly in production code when testability is needed.
- In tests, use `MockOSManager.environment` to simulate different PATH configurations.

### 7. Testing Guidelines
- **Always test on WSL first**: Use the `MockOSManager` (or `FakeOSManager` in tests) to verify logic without needing Windows.
- **Test edge cases**: Invalid paths, missing versions, symlink failures, absence of Composer in PATH.
- **Test organization**: Place unit tests in dedicated files matching the feature:
  - Command tests: `test/commands/<command_name>_test.dart`
  - Service tests: `test/services/<service_name>_test.dart`
  - Core component tests: `test/core/`
  - Process manager tests: `test/process/`
- **Test doubles**: Use `FakeOSManager` and `FakeProcessManager` from `test/services/` for mocking. They provide configurable behavior and call tracking.
- **Regression tests**: When modifying existing functionality, ensure all related tests still pass. Add new tests for uncovered edge cases.

## Project Structure

- `pvm.dart`: The entry point. Uses `CommandRunner` for command dispatching.
- `lib/src/`:
  - `commands/`: Command files (`global_command.dart`, `use_command.dart`, `list_command.dart`, `php_command.dart`, `composer_command.dart`).
  - `core/`: Contains `os_manager.dart` (OS abstractions), `process_manager.dart` (process spec & interface), `php_version_manager.dart`, `gitignore_service.dart`.
  - `managers/`:
    - `windows_os_manager.dart`: Windows-specific implementation.
    - `mock_os_manager.dart`: Mock implementation for testing.
  - `process/`:
    - `io_process_manager.dart`: Cross-platform process execution using Dart's `Process` API.
    - `process.dart` (if present)
  - `services/`:
    - `php_executor.dart`: Service for executing PHP and PHP scripts with local version.
- `test/`:
  - `commands/`: Command tests (`php_command_test.dart`, `composer_command_test.dart`, etc.)
  - `services/`: Service tests (`php_executor_test.dart`) and test doubles (`fake_os_manager.dart`, `fake_process_manager.dart`)
  - `core/`: Core component tests
  - `process/`: Process manager tests
  - `mock_test.dart`: Mock infrastructure tests
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

### Process Execution Details

- **`IOProcessManager`**: Uses Dart's `Process.start` with `ProcessStartMode.normal` (not `inheritStdio`) to avoid SDK issues with process termination. Manually pipes stdin from parent (best-effort), and streams stdout/stderr to the console. This ensures long-running processes like `php artisan serve` work reliably.
- **`IOProcessManager.runCaptured`**: Uses `Process.run` to capture output synchronously for non-interactive commands.
- **No Job Objects**: The current implementation does not use Windows Job Objects or custom FFI. Process lifecycle management is handled by Dart's standard `Process` API.

**Note**: The previous documentation described a Job Objects system that has since been removed in favor of a simpler cross-platform approach.

## Common Pitfalls

1. **Developer Mode**: If symlink creation fails, check if Developer Mode is enabled in Windows Settings.
2. **WSL Testing**: On WSL, always use `MockOSManager` - never try to run Windows-specific code.
3. **Path Separators**: Always use `package:path` (`p.join()`) for building paths; never hardcode backslashes even on Windows. The `path` package ensures cross-platform correctness and avoids subtle bugs.

## Rule Integration

Follow standard Dart `lints` package recommendations as configured in `pubspec.yaml`.

## Plan Persistence

When working on significant features or refactoring, create a plan document to track progress.

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

### Progress Log
Add a progress log section to each plan:
```markdown
## Progress Log

### YYYY-MM-DD
- [Description of work completed]
- [Another item]
```

**IMPORTANT**: Always update the plan .md file as you progress through implementation. Include dates and specific changes made.

---

## Git Operations Policy

### CRITICAL RESTRICTION

**AGENTS MUST NEVER PERFORM GIT OPERATIONS WITHOUT EXPLICIT USER PERMISSION.**

This includes but is not limited to:
- `git add`, `git commit`, `git push`, `git pull`
- `git rebase`, `git merge`, `git reset`, `git stash`
- Any git command execution via bash or other tools

**Why**: Git operations are high-impact and can cause data loss, rewrite history, or disrupt collaboration. They require human oversight and decision-making.

**Proper Workflow**:
1. Agent performs all code changes and testing
2. Agent reports what changes were made and provides evidence (test outputs, etc.)
3. User reviews and decides to commit
4. User (or user explicitly authorizing agent) performs git operations

**Exception**: The `git-master` skill may be invoked *by the user* to assist with commit creation, but even then the final commit command must be explicitly executed with user approval or by the user themselves.

**Violation**: Any agent autonomously executing git commands will be considered a critical failure. Agents that do so will be reported and have their privileges revoked.

---

## Plan Mode Guidelines

Plan mode is a read-only mode for research, planning, and exploration before implementation.

### When to Use Plan Mode
- When the user asks to "plan" something
- When researching unfamiliar APIs or libraries
- When breaking down complex tasks into steps
- When exploring multiple approaches before deciding

### Plan Mode Workflow
1. Use explore agents or websearch to gather information
2. Present findings and options to the user
3. Create/update a plan document with the chosen approach
4. Wait for user confirmation before implementing

### Fix Plan Format
When presenting a fix plan, always include:
```markdown
### Fix: [Issue Name]

**Status:** [To Do / In Progress / Completed]

**Problem:** [Description of the bug]

**Solution:** [How to fix it]

**File to Modify:** [File path]

**Steps:**
1. [Step]
2. [Step]

**Expected Result:** [What should happen after the fix]
```

---

## Parallel Subagent Execution

When working on complex tasks, identify independent tasks that can run in parallel to speed up research and implementation.

### When to Use Parallel Execution
- Multiple phases can run independently
- Researching different aspects of a problem simultaneously
- Creating multiple files that don't depend on each other

### How to Execute in Parallel
1. Launch multiple Task tools with explore subagent type
2. Wait for all results to complete
3. Combine findings before proceeding

### Example
```dart
// Launch 3 explore agents in parallel
task(description="Research CommandRunner", prompt="...", subagent_type="explore")
task(description="Research FFI bindings", prompt="...", subagent_type="explore")  
task(description="Research Job Objects", prompt="...", subagent_type="explore")
```

---

## Websearch in Plan Mode

Use websearch and codesearch tools extensively in plan mode to gather relevant documentation, examples, and best practices.

### When to Use
- When researching unfamiliar APIs
- When needing current documentation
- When looking for code examples
- When exploring alternative approaches

### How to Use
1. Use websearch for general documentation
2. Use codesearch for code-specific examples
3. Include relevant findings in the plan document

### Example Queries
- "Dart CommandRunner subcommand example"
- "Windows Job Objects FFI dart win32"
- "dart ffi lookupFunction example"
