Draft: GitIgnoreService + Root .php-version (CLI-only defaults)

Goal: Capture the design decisions for no-env-var overrides, CLI flags, and DI wiring for both features.

Key decisions:
- Root path defaults to repository root; override via --root-path on commands.
- Symlink creation best-effort; non-fatal warnings if symlink cannot be created.
- Interactive prompts in TTY; non-interactive fallback with --no-prompt; --auto-accept for automation.
- No Git existence checks; the services operate as-if Git may be present and handle gracefully if not.
- DI: Use constructor injection for GitIgnoreService and PhpVersionManager into UseCommand and related commands.

Next steps:
- Implement lib/src/core/gitignore_service.dart and lib/src/core/php_version_manager.dart.
- Wire new services into lib/src/commands/use_command.dart and tests.
- Create tests for the new behavior and update plan docs accordingly.
