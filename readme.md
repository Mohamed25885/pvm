# PVM — PHP Version Manager for Windows

A command-line tool for managing multiple PHP versions on Windows. PVM lets you switch between PHP versions per-project or globally, using Windows symbolic links for fast, zero-overhead version switching.

**Latest release:** [v1.2.0](https://github.com/Mohamed25885/pvm/releases/tag/v1.2.0) — adds `pvm current`, `pvm doctor`, `pvm uninstall`, and `pvm exec`, plus diagnostics and symlink tooling. See [CHANGELOG.md](CHANGELOG.md).

---

## Table of Contents

- [Installation](#installation)
- [Commands](#commands)
- [`pvm global <version>`](#pvm-global-version)
- [`pvm use <version>`](#pvm-use-version)
- [`pvm list`](#pvm-list)
- [`pvm current`](#pvm-current)
- [`pvm doctor`](#pvm-doctor)
- [`pvm exec`](#pvm-exec)
- [`pvm uninstall`](#pvm-uninstall)
- [`pvm install` / `pvm list-remote`](#pvm-install--pvm-list-remote)
- [`pvm php [arguments]`](#pvm-php-arguments)
- [`pvm composer [arguments]`](#pvm-composer-arguments)
- [`pvm version`](#pvm-version)
- [How It Works](#how-it-works)
  - [Directory Structure](#directory-structure)
  - [Project Root Discovery](#project-root-discovery)
  - [The `.php-version` File](#the-php-version-file)
  - [Global vs Local Versions](#global-vs-local-versions)
  - [The `pvm php` Proxy](#the-pvm-php-proxy)
- [Interactive vs Non-Interactive Mode](#interactive-vs-non-interactive-mode)
- [Requirements](#requirements)
- [Development](#development)

---

## Platform Support

**Current**: Windows 10/11 only  
**Requirements**:
- Symbolic link support (Developer Mode enabled OR Administrator privileges)
- PowerShell or CMD

**Planned**: Linux and macOS support in future releases.

---

## Installation

1. **Download or build** the `pvm.exe` binary.
2. **Place `pvm.exe` in a permanent location** (e.g., `C:\Tools\pvm\pvm.exe`).
3. **Create the versions directory** alongside the executable:
   ```
   C:\Tools\pvm\
   ├── pvm.exe
   └── versions\
       ├── 8.0\
       │   └── php.exe
       └── 8.2\
           └── php.exe
   ```
4. **Add the pvm directory to your PATH**, or run pvm using its full path.
5. **Enable Developer Mode** (recommended) or run as Administrator — required for creating symbolic links on Windows.

---

## Commands

### `pvm global <version>`

Sets the **system-wide** PHP version. The symlink is created at `%USERPROFILE%\.pvm`, which must be added to your PATH to use globally.

```powershell
pvm global 8.2
# Global link created: C:\Users\<you>\.pvm -> C:\Tools\pvm\versions\8.2
# Add "C:\Users\<you>\.pvm" to your PATH to use globally
```

**Requirements:**
- Version must already exist in the `versions/` directory
- Version format: `x.y` or `x.y.z` (e.g., `8.2`, `8.2.1`)

---

### `pvm use <version>`

Sets the **project-local** PHP version by creating a `.pvm` symlink in the project root and writing the version to `.php-version`.

```powershell
cd C:\Projects\MyApp
pvm use 8.0
# Local link created: C:\Projects\MyApp\.pvm -> C:\Tools\pvm\versions\8.0
```

**What happens on `pvm use`:**

1. **GitIgnoreService runs** — ensures `.gitignore` exists and contains `.pvm` entry
2. **Best-effort symlink creation** — attempts to create `.pvm` symlink pointing to `versions/`
3. **`.php-version` is written** with the selected version as JSON
4. **Mismatch prompt** (interactive mode) — if `.php-version` has a different version, asks for confirmation. Default is **Yes** (press Enter to confirm).
5. **Non-installed version** — if the requested version isn't in `versions/`, prompts you to pick from available versions

**No version argument:** Reads from `.php-version` file in the project root and applies that version.

```powershell
cd C:\Projects\MyApp  # .php-version exists here
pvm use               # reads .php-version and applies that version
```

**Version format validation:**
```
pvm use 8.2        # OK
pvm use 8.2.1      # OK
pvm use stable     # ERROR: Invalid version format. Expected: x.y or x.y.z
```

---

### `pvm list`

Lists all PHP versions available in the `versions/` directory.

```powershell
pvm list
# 8.0
# 8.2
```

---

### `pvm current`

Shows the **effective** PHP version for your environment: global (`%USERPROFILE%\.pvm`) and, from the current directory, project-local (`<project>\.pvm`). Local scope overrides global when both are set. Broken or orphaned symlinks are reported explicitly.

```powershell
pvm current
pvm current --global-only
pvm current --local-only
pvm current --json
```

---

### `pvm doctor`

Runs environment checks (versions directory, symlink targets, PATH hints, and optionally a live symlink-creation probe). Use `--no-symlink-test` to skip the probe.

```powershell
pvm doctor
pvm doctor --json
pvm doctor --no-symlink-test
```

---

### `pvm exec`

Runs a command with a chosen **installed** PHP version on `PATH`. Use `--version <ver>` or an optional **first positional** version (only if that token parses as a version **and** is installed). Use `--cwd <dir>` to set the working directory. After optional `--`, the rest is the command line.

- **`php …`** — forwarded through `PhpExecutor` with the selected PHP.
- **`composer …`** — Composer is resolved via PATH / locator; runs with the selected PHP.
- **Anything else** — spawned with the selected PHP’s `bin` directory prepended to `PATH`.

```powershell
pvm exec 8.2 -- php -v
pvm exec --version 8.2 -- php -v
pvm exec --cwd C:\Projects\MyApp -- composer install
```

If the first token looks like a version but is **not** installed, PVM exits with an error instead of treating it as part of the command.

---

### `pvm uninstall`

Removes an installed version directory under `versions/`.

| Flag | Meaning |
|------|---------|
| `--yes` / `-y` | Skip the confirmation prompt (does **not** bypass the active-global guard). |
| `--force` | Allow uninstalling the version targeted by the **active global** symlink; implies `--yes`. |
| `--keep-symlinks` | Do not remove symlinks that would become dangling after the directory is deleted. |

```powershell
pvm uninstall 8.1.0
pvm uninstall 8.1.0 --yes
pvm uninstall 8.1.0 --force
```

---

### `pvm install` / `pvm list-remote`

Download and install PHP builds from the configured release source, and list available remote versions. See `pvm install --help` and `pvm list-remote --help` for architecture and build-type options.

```powershell
pvm list-remote
pvm install 8.3
```

---

### `pvm php [arguments]`

Runs PHP using the **local** version configured for the current project. All arguments are forwarded unchanged to PHP.

```powershell
cd C:\Projects\MyApp
pvm php --version
pvm php artisan serve
pvm php -d memory_limit=256M script.php
```

**How it works:**

1. **Project root discovery** — walks up from the current directory looking for a `.php-version` file. Its parent directory is the project root.
2. **Local symlink check** — looks for `<project-root>\.pvm` pointing to a PHP installation.
3. **Executes** the PHP executable from the symlink target, with `workingDirectory` set to the project root.

**Error states:**
- No `.pvm` directory found → `Error: No local version configured. Run "pvm use <version>" first.`
- PHP executable missing → `Error: PHP executable not found at <path>`

---

### `pvm composer [arguments]`

Runs Composer using the **local** PHP version configured for the current project. The Composer script is located via the system PATH (supports `composer.bat`, `composer.phar` on Windows; `composer`, `composer.phar` on Unix). All arguments are forwarded unchanged to Composer.

```powershell
cd C:\Projects\MyApp
pvm composer --version
pvm composer install
pvm composer require laravel/framework
```

**How it works:**

1. **Project root discovery** — walks up from the current directory looking for a `.php-version` file. Its parent directory is the project root.
2. **Local symlink check** — looks for `<project-root>\.pvm` pointing to a PHP installation.
3. **Composer script lookup** — searches the system PATH for an executable named `composer` (or `composer.bat` / `composer.phar` on Windows).
4. **Executes** Composer using the local PHP interpreter, with `workingDirectory` set to the project root.

**Error states:**
- No local PHP version configured → `Error: No local version configured. Run "pvm use <version>" first.`
- Composer script not found in PATH → `Error: Composer not found in PATH. Install Composer globally or ensure it's accessible.`
- PHP executable missing → `Error: PHP executable not found at <path>`

**Note:** If Composer is installed locally in your project (e.g., `vendor/bin/composer`), use `pvm php vendor/bin/composer` instead. `pvm composer` expects a global Composer installation accessible via PATH.

---

### `pvm version`

Prints the PVM CLI version (from `pubspec.yaml` / generated `lib/src/version.dart`).

```powershell
pvm version
# PVM version: <matches your build, e.g. 1.2.0>
```

---

## How It Works

### Directory Structure

```
C:\Tools\pvm\               <- PVM installation (where pvm.exe lives)
├── pvm.exe
└── versions\              <- All PHP installations live here
    ├── 8.0\
    │   └── php.exe
    └── 8.2\
        └── php.exe

C:\Users\<you>\            <- Your user home directory
└── .pvm -> C:\Tools\pvm\versions\8.2   <- Global symlink (add to PATH)

C:\Projects\MyApp\         <- Your project
├── .php-version           <- Stores the selected version (JSON)
├── .pvm -> C:\Tools\pvm\versions\8.0   <- Local symlink
└── .gitignore             <- Contains ".pvm/" entry
```

### Project Root Discovery

When you run `pvm use`, `pvm php`, or `pvm composer`, PVM walks up from your current working directory looking for a `.php-version` file. The **parent directory** of `.php-version` is treated as the project root. This allows you to run PVM from any subdirectory of your project.

```
C:\Projects\MyApp\src\api> pvm use 8.2
# Walks up: src/api → src → MyApp (finds .php-version here)
# Project root: C:\Projects\MyApp
# .php-version: C:\Projects\MyApp\.php-version
# .pvm symlink: C:\Projects\MyApp\.pvm
```

If no `.php-version` is found, the current working directory is used as the root.

### The `.php-version` File

Stores the project's selected PHP version in JSON format:

```json
{
  "version": "8.2"
}
```

- **`pvm use <version>`** — writes the version to `.php-version`
- **`pvm use`** (no argument) — reads from `.php-version` and applies that version
- **Mismatch detection** — when switching versions, if `.php-version` differs from the requested version, prompts for confirmation (interactive) or auto-applies without updating the file (non-interactive)

### Global vs Local Versions

| Aspect | Global | Local |
|---|---|---|
| **Command** | `pvm global <version>` | `pvm use <version>` |
| **Symlink location** | `%USERPROFILE%\.pvm` | `<project-root>\.pvm` |
| **Scope** | System-wide | Project-specific |
| **Version file** | None | `.php-version` |
| **PATH required?** | Yes (add `%USERPROFILE%\.pvm` to PATH) | No |
| **Use with `pvm php`** | No | Yes |

### The `pvm php` Proxy

`pvm php` always uses the **local** version (from `<project-root>\.pvm`), not the global one. It:

1. Discovers the project root from the current working directory
2. Reads the `.pvm` symlink to find the PHP executable
3. Executes PHP with `workingDirectory` set to the project root

This means commands like `php artisan` and `composer` run in the correct project context, regardless of which subdirectory you're in.

---

## Interactive vs Non-Interactive Mode

PVM detects whether it has a terminal attached:

**Interactive** (has TTY):
- Mismatch prompt: `Detected .php-version contains "8.0". Switch to "8.2"? (Y/n): `
- Default is **Yes** — press Enter to confirm
- Version picker when a version isn't installed

**Non-Interactive** (no TTY — CI/CD pipelines, scripts):
- No prompts
- Mismatch: auto-applies the requested version, does **not** update `.php-version`
- Missing version: exits with error code 1

---

## Requirements

### Developer Mode (Recommended)

Windows requires **Developer Mode** enabled for non-admin users to create symbolic links. Without it, symlink creation fails with `Access is denied`.

**Enable Developer Mode:**
1. Open **Settings** → **Privacy & security** → **For developers**
2. Toggle **Developer Mode** to **On**

### Alternative: Run as Administrator

If Developer Mode is not enabled, run Command Prompt or PowerShell as Administrator before using PVM.

### Symlink Behavior

- `pvm use` creates symlinks using `mklink /D`
- Symlinks are **best-effort**: if creation fails (permissions, Developer Mode), the command reports the error but continues other operations
- Existing `.pvm` files/directories are replaced with the symlink

---

## Development

### Project Structure

- `pvm.dart` — entry point and `CommandRunner` registration  
- `lib/src/commands/` — `global`, `use`, `list`, `current`, `doctor`, `exec`, `uninstall`, `install`, `list-remote`, `php`, `composer`, `version`  
- `lib/src/core/` — `IOSManager` (incl. symlink helpers), `SymLinkInspector`, `ActiveVersionResolver`, `PhpVersionManager`, `Console`, process/exec resolution, …  
- `lib/src/domain/` — project root, version registry, `PhpVersion`, …  
- `lib/src/services/` — `PhpExecutor`, `diagnostics/` (doctor checks)  
- `lib/src/managers/` — Windows implementation; Linux/mac variants for tests and non-Windows runs  
- `lib/src/process/` — `IOProcessManager`  
- `test/mocks/mock_os_manager.dart` — primary test double for commands and services  

### Key Paths

| Path | Meaning |
|---|---|
| `programDirectory` | Where `pvm.exe` lives — contains `versions/` |
| `phpVersionsPath` | `<programDirectory>\versions` |
| `currentDirectory` | Where the user runs PVM from |
| `rootPath` | Project root — discovered by `.php-version` location |
| `localPath` | `<rootPath>\.pvm` — local version symlink |
| `homeDirectory` | `%USERPROFILE%` — where global symlink lives |

### Commands

```powershell
# Analyze code
dart analyze

# Format code
dart format .

# Run tests
dart test

# Build executable
dart compile exe pvm.dart -o builds/pvm.exe
```

### Testing

Tests use `MockOSManager` (`test/mocks/mock_os_manager.dart`) to simulate filesystem operations without requiring Windows. The mock:

- Uses a real `currentDirectory` override for PhpCommand root discovery
- Has a conservative default (directories/files don't exist unless explicitly mocked)
- Supports `symlinkSourceExistsOverride = true` to simulate installed versions

---

## Troubleshooting

### Symlink creation fails: `Access is denied`

Enable **Developer Mode** in Windows Settings, or run the terminal as Administrator.

### `pvm use` says "Version directory not found"

The version doesn't exist in the `versions/` directory. Run `pvm list` to see what's available.

### `pvm php` says "No local version configured"

Run `pvm use <version>` first to create the local `.pvm` symlink.

### Multiple `.php-version` files found

PVM uses the **first** `.php-version` found when walking up from the current directory. Make sure you don't have stray `.php-version` files in parent directories.
