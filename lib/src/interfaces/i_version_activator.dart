/// OS-level version switching for PHP installations.
///
/// This interface abstracts platform-specific symlink operations:
/// - **Windows**: Creates symlinks via `mklink /D`
/// - **Linux**: Updates alternatives via `update-alternatives`
/// - **macOS**: Creates symlinks via `ln -s`
///
/// ## Responsibilities
///
/// The activator is **only responsible for symlink creation**. It does NOT:
/// - Download or extract PHP archives (handled by the installer)
/// - Manage version metadata
/// - Handle PATH configuration
///
/// ## When each method is called
///
/// - [activateGlobal]: Invoked when the user runs `pvm global <version>`
///   Creates a system-wide symlink in the user's home directory
///   (e.g., `%USERPROFILE%\.pvm` on Windows). This symlink should be
///   added to the user's PATH for global access.
///
/// - [activateLocal]: Invoked when the user runs `pvm use <version>`
///   Creates a project-local symlink (e.g., `<project-root>\.pvm`) that
///   points to the PHP installation in the versions directory. The
///   project root is discovered by walking up from the current directory
///   until a `.php-version` file is found.
abstract class IVersionActivator {
  /// Activate a version as the system-wide/global PHP.
  ///
  /// Called when the user runs `pvm global <version>`. Creates a symlink
  /// at the platform-specific global location (e.g., `~/.pvm` on Unix,
  /// `%USERPROFILE%\.pvm` on Windows).
  ///
  /// [version] - the PHP version to activate globally (e.g., "8.2", "8.2.1")
  Future<void> activateGlobal(String version);

  /// Activate a version for the current project (local).
  ///
  /// Called when the user runs `pvm use <version>`. Creates a symlink
  /// in the project root directory (discovered via `.php-version` location).
  /// This allows `pvm php` to resolve the correct PHP executable for the
  /// current project.
  ///
  /// [version] - the PHP version to activate locally (e.g., "8.2", "8.2.1")
  Future<void> activateLocal(String version);
}
