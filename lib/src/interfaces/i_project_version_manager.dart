/// Project version manager interface for managing .php-version file.
///
/// Handles reading/writing the .php-version file in project directories.
abstract class IProjectVersionManager {
  /// Set the local PHP version for a project.
  /// [version] - the PHP version to set
  Future<void> setLocalVersion(String version);

  /// Get the current local PHP version for a project.
  /// Returns: the version string or null if not set
  Future<String?> getLocalVersion();

  /// Check if a local version is configured for the project.
  Future<bool> hasLocalVersion();

  /// Get the project root directory path.
  String get projectRoot;
}
