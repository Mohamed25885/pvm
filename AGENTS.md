# AGENTS.md

This document provides essential information for agentic coding agents working in the PVM (PHP Version Manager) repository.

## Project Overview

PVM is a Dart-based command-line tool designed to manage multiple PHP versions on Windows. It allows users to switch between global and local PHP versions by creating symbolic links and provides a proxy to run PHP commands through the selected version.

## Environment & Dependencies

- **Language:** Dart (SDK ^3.4.0)
- **Target Platform:** Windows (strictly uses Windows-specific APIs and path conventions)
- **Key Dependencies:**
  - `args`: Command-line argument parsing.
  - `ffi` & `win32`: Interaction with Windows APIs (e.g., for process management and cleanup).
  - `path`: Path manipulation (though some manual string concatenation with `\` exists).

## Critical Commands

### Development & Maintenance
- **Analyze Code:** `dart analyze`
- **Format Code:** `dart format .`
- **Fix Lints:** `dart fix --apply`

### Execution
- **Run locally:** `dart pvm.dart <command> [arguments]`
- **Run PHP proxy:** `dart pvm.dart php -- <php-args>`

### Build
- **Compile Executable:** `dart compile exe pvm.dart -o builds/pvm.exe`

### Testing
- **Run all tests:** `dart test` (Note: No tests currently exist; create the `test/` directory if adding them).
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

## Project Structure

- `pvm.dart`: The entry point. Handles argument parsing and command dispatching.
- `enums/`: Contains `Options` enum defining the CLI interface.
- `utils/`:
  - `utils.dart`: General utility functions and path discovery.
  - `option_creator.dart`: Logic for setting up global/local environments.
  - `php_proxy.dart`: Manages the lifecycle of the proxied PHP process.
  - `symlink_creator.dart`: Handles Windows symbolic link creation.
  - `gitngore.dart`: Helper to update `.gitignore` files.
- `versions/`: (Ignored in git) Should contain subdirectories for each PHP version.
- `builds/`: Destination for compiled executables.

## Implementation Details to Remember

- **PHP Proxy:** When running `pvm php`, the tool starts the PHP process and pipes `stdin`/`stdout`/`stderr`. It also implements a Windows message loop to handle cleanup if the parent terminal is closed.
- **Symlinks:** Creating local/global versions relies on Windows symbolic links. Ensure the process has sufficient permissions or the user is informed if creation fails.
- **Local Config:** Local versions are managed via a `.pvm` directory in the current working directory.

## Rule Integration

No project-specific Cursor or Copilot rules were found. Follow standard Dart `lints` package recommendations as configured in `pubspec.yaml`.
