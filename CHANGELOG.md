# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased](https://github.com/Mohamed25885/pvm/compare/v1.0.1...HEAD)

## [1.0.1] - 2026-04-18

### Added
- Composer proxy command (`pvm composer`)
- `pvm version` flag support
- Console UI improvements with colors and formatting
- Exit codes module for better error handling

### Fixed
- Various bug fixes and improvements

---

## [1.0.0] - 2025-03-25

### Added

- Initial release of PVM (PHP Version Manager)
- `pvm global` command to set system-wide PHP version
- `pvm use` command to set project-local PHP version
- `pvm list` command to list available PHP versions
- `pvm php` proxy to run PHP with local version
- `pvm composer` proxy to run Composer with local PHP
- Windows symbolic link management for fast version switching
- Interactive and non-interactive mode support
- Project root discovery via `.php-version` file
- Automatic `.gitignore` management for `.pvm` directory
- Version format validation (x.y or x.y.z)
- Mismatch detection and confirmation prompts
- Support for Developer Mode and Administrator privileges

---

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). All future changes will be documented in the [Unreleased] section above and moved to a new version section upon release.
