# PVM — PHP Version Manager for Windows

A command-line tool for managing multiple PHP versions on Windows. PVM lets you switch between PHP versions per-project or globally, using Windows symbolic links for fast, zero-overhead version switching.

**Latest release:** [v2.0.0](https://github.com/Mohamed25885/pvm/releases/tag/v2.0.0) — `.pvmrc` config (replaces `.php-version`), `pvm setup`, privilege-escalation for symlinks, `major.minor` version shorthand, optional `PVM_HOME` / `PVM_VERSIONS_HOME`. See [CHANGELOG.md](CHANGELOG.md).

**Upgrading from v1.x:** Run `pvm use <version>` in each project to create `.pvmrc`, or add `.pvmrc` manually. Remove legacy `.php-version` files if present (PVM ignores them).

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
- [`pvm setup`](#pvm-setup)
- [`pvm install` / `pvm list-remote`](#pvm-install--pvm-list-remote)
- [`pvm php [arguments]`](#pvm-php-arguments)
- [`pvm composer [arguments]`](#pvm-composer-arguments)
- [`pvm version`](#pvm-version)
- [How It Works](#how-it-works)
  - [Directory Structure](#directory-structure)
  - [Project Root Discovery](#project-root-discovery)
  - [The `.pvmrc` File](#the-pvmrc-file)
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

1. **Download** `pvm.exe` from [GitHub Releases](https://github.com/Mohamed25885/pvm/releases) (or build locally; see [Development](#development)).
2. **Place `pvm.exe` in a permanent location** (e.g., `C:\Tools\pvm\pvm.exe`).
3. **Run setup** (recommended):
   ```powershell
   pvm setup --dry-run   # preview directories, env vars, and PATH changes
   pvm setup             # apply after reviewing
   ```
   Setup may create `versions\` beside the executable, optionally set **`PVM_HOME`** (directory containing `pvm.exe`) and **`PVM_VERSIONS_HOME`** (PHP versions root, default `%PVM_HOME%\versions`), and add PATH entries for the `pvm` folder and `%USERPROFILE%\.pvm`. **Env vars are optional** — if unset, PVM uses the same layout as before (`<exe-dir>/versions`).
4. **Manual layout** (if you skip `pvm setup`):
   ```
   C:\Tools\pvm\
   ├── pvm.exe
   └── versions\
       ├── 8.0\
       │   └── php.exe
       └── 8.2\
           └── php.exe
   ```
   Add the `pvm` directory and `%USERPROFILE%\.pvm` to your PATH as needed.
5. **Enable Developer Mode** (recommended) or run as Administrator — required for creating symbolic links on Windows.

---

## Commands

### Version shorthand (`major.minor`)

For **`pvm use`**, **`pvm global`**, **`pvm exec`**, and **`pvm uninstall`**, you may pass `major.minor` (e.g. `8.4`) instead of a full patch when **exactly one** installed version matches that line (e.g. only `8.4.1` is installed). If multiple patches are installed (e.g. `8.4.0` and `8.4.1`), you must specify the full version (`8.4.1`). `pvm install` is unchanged (it selects from remote releases, not installed folders).

---

### `pvm global <version>`

Sets the **system-wide** PHP version. The symlink is created at `%USERPROFILE%\.pvm`, which must be added to your PATH to use globally.

```powershell
pvm global 8.2
# Global link created: C:\Users\<you>\.pvm -> C:\Tools\pvm\versions\8.2
# Add "C:\Users\<you>\.pvm" to your PATH to use globally
```

**Requirements:**
- Version must already exist in the `versions/` directory
- Version format: `x.y` or `x.y.z` (e.g., `8.2`, `8.2.1`); `x.y` resolves automatically when unambiguous (see [Version shorthand](#version-shorthand-majorminor))

---

### `pvm use <version>`

Sets the **project-local** PHP version by creating a `.pvm` symlink in the project root and writing the version to `.pvmrc`.

```powershell
cd C:\Projects\MyApp
pvm use 8.0
# Local link created: C:\Projects\MyApp\.pvm -> C:\Tools\pvm\versions\8.0
```

**What happens on `pvm use`:**

1. **GitIgnoreService runs** — ensures `.gitignore` exists and contains `.pvm` entry
2. **Symlink creation** — creates `.pvm` symlink pointing to `versions/`; on permission denial, may prompt to retry with elevation
3. **`.pvmrc` is written** with the selected version as JSON
4. **Mismatch prompt** (interactive mode) — if `.pvmrc` has a different version, asks for confirmation. Default is **Yes** (press Enter to confirm).
5. **Non-installed version** — if the requested version isn't in `versions/`, prompts you to pick from available versions

**No version argument:** Reads from `.pvmrc` file in the project root and applies that version.

```powershell
cd C:\Projects\MyApp  # .pvmrc exists here
pvm use               # reads .pvmrc and applies that version
```

**Version format validation:**
```
pvm use 8.2        # OK (resolves to 8.2.x when only one match)
pvm use 8.2.1      # OK
pvm use 8.2        # ERROR if both 8.2.0 and 8.2.1 installed (ambiguous)
pvm use stable     # ERROR: Invalid version format. Expected: x.y or x.y.z
```

---

### `pvm setup`

Configures PVM on Windows: preflight checks (directories, permissions), optional user environment variables, and PATH.

| Flag | Meaning |
|------|---------|
| `--dry-run` | Show planned changes only; do not write env or create directories |
| `--yes` / `-y` | Skip confirmation before applying changes |
| `--versions-home <path>` | Override default `PVM_VERSIONS_HOME` before writing env |

```powershell
pvm setup --dry-run
pvm setup --yes
pvm setup --versions-home D:\php-versions
```

**Environment variables (optional):**

| Variable | When set | When unset |
|----------|----------|------------|
| `PVM_HOME` | Directory containing `pvm.exe` | Executable's parent directory |
| `PVM_VERSIONS_HOME` | Root of installed PHP versions | `%PVM_HOME%\versions` |

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

If the first token looks like a version but is **not** installed (or is ambiguous — multiple `8.2.x` installed), PVM exits with an error instead of treating it as part of the command.

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

1. **Project root discovery** — walks up from the current directory looking for a `.pvmrc` file. Its parent directory is the project root.
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

1. **Project root discovery** — walks up from the current directory looking for a `.pvmrc` file. Its parent directory is the project root.
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
# PVM version: 2.0.0
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
├── .pvmrc           <- Stores the selected version (JSON)
├── .pvm -> C:\Tools\pvm\versions\8.0   <- Local symlink
└── .gitignore             <- Contains ".pvm/" entry
```

### Project Root Discovery

When you run `pvm use`, `pvm php`, or `pvm composer`, PVM walks up from your current working directory looking for a `.pvmrc` file. The **parent directory** of `.pvmrc` is treated as the project root. This allows you to run PVM from any subdirectory of your project.

```
C:\Projects\MyApp\src\api> pvm use 8.2
# Walks up: src/api → src → MyApp (finds .pvmrc here)
# Project root: C:\Projects\MyApp
# .pvmrc: C:\Projects\MyApp\.pvmrc
# .pvm symlink: C:\Projects\MyApp\.pvm
```

If no `.pvmrc` is found, PVM walks up for a **`.pvm/`** directory (existing local symlink). If neither exists, the current working directory is used as the root.

### The `.pvmrc` File

Stores the project's selected PHP version as JSON (not plain text — this avoids filename clashes with Apache and other `.php-version` tooling):

```json
{
  "version": "8.2"
}
```

- **`pvm use <version>`** — writes the version to `.pvmrc`
- **`pvm use`** (no argument) — reads from `.pvmrc` and applies that version
- **Mismatch detection** — when switching versions, if `.pvmrc` differs from the requested version, prompts for confirmation (interactive) or auto-applies without updating the file (non-interactive)

### Global vs Local Versions

| Aspect | Global | Local |
|---|---|---|
| **Command** | `pvm global <version>` | `pvm use <version>` |
| **Symlink location** | `%USERPROFILE%\.pvm` | `<project-root>\.pvm` |
| **Scope** | System-wide | Project-specific |
| **Version file** | None | `.pvmrc` |
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
- Mismatch prompt: `Detected .pvmrc contains "8.0". Switch to "8.2"? (Y/n): `
- Default is **Yes** — press Enter to confirm
- Version picker when a version isn't installed

**Non-Interactive** (no TTY — CI/CD pipelines, scripts):
- No prompts
- Mismatch: auto-applies the requested version, does **not** update `.pvmrc`
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

- `pvm use` / `pvm global` create symlinks using `Link.create` (Windows: requires Developer Mode or Administrator).
- On permission denial, PVM may prompt to retry with elevated permissions when a terminal is attached.
- Existing `.pvm` files/directories are replaced with the symlink when creation succeeds.

---

## Development

### Project Structure

- `pvm.dart` — entry point and `CommandRunner` registration  
- `lib/src/commands/` — `setup`, `global`, `use`, `list`, `current`, `doctor`, `exec`, `uninstall`, `install`, `list-remote`, `php`, `composer`, `version`  
- `lib/src/core/` — `IOSManager`, `ElevatingOSManager`, `PvmPaths`, `SymLinkInspector`, `ActiveVersionResolver`, `PhpVersionManager`, `Console`, …  
- `lib/src/domain/` — `Project`, `InstalledVersionResolver`, version registry, `PhpVersion`, …  
- `lib/src/services/` — `PhpExecutor`, `installation/` (`PvmSetupService`), `privilege_escalation_service.dart`, `diagnostics/`  
- `lib/src/managers/` — Windows implementation; Linux/mac variants for tests and non-Windows runs  
- `lib/src/process/` — `IOProcessManager`  
- `test/mocks/mock_os_manager.dart` — primary test double for commands and services  

### Key Paths

| Path | Meaning |
|---|---|
| `PVM_HOME` (env) | Optional; directory containing `pvm.exe` (default: executable's parent) |
| `PVM_VERSIONS_HOME` (env) | Optional; root of installed PHP versions (default: `<PVM_HOME>/versions`) |
| `programDirectory` | Resolved install root — where `pvm.exe` lives |
| `phpVersionsPath` | Resolved versions directory |
| `currentDirectory` | Where the user runs PVM from |
| `rootPath` | Project root — discovered by `.pvmrc` or `.pvm/` marker |
| `localPath` | `<rootPath>\.pvm` — local version symlink |
| `homeDirectory` | `%USERPROFILE%` — where global symlink lives (unless `PVM_HOME` overrides layout) |

### SDK (FVM)

This project uses [FVM](https://fvm.app) with **Flutter 3.41.6**, which bundles **Dart 3.11.4** (see [`.fvmrc`](.fvmrc)). PVM is a Dart CLI app, not a Flutter app; the Flutter SDK is only used to supply a pinned Dart toolchain.

```powershell
# One-time: install FVM (https://fvm.app) and the project SDK
fvm install
fvm use 3.41.6 --force

# Always prefix Dart commands with fvm (or use IDE .vscode/settings.json)
fvm dart pub get
fvm dart --version   # Dart SDK version: 3.11.4
```

### Commands

```powershell
# Analyze code
fvm dart analyze

# Format code
fvm dart format .

# Run tests
fvm dart test

# Run CLI locally
fvm dart run pvm.dart current

# Build executable
fvm dart compile exe pvm.dart -o builds/pvm.exe
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

### Multiple `.pvmrc` files found

PVM uses the **first** `.pvmrc` found when walking up from the current directory. Make sure you don't have stray `.pvmrc` files in parent directories.
