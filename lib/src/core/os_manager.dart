/// OS abstraction layer for platform-specific operations.
///
/// Current implementation: WindowsOSManager only.
/// Future: LinuxOSManager, MacOSManager when cross-platform support is added.
abstract interface class IOSManager {
  Future<({String from, String to})> createSymLink(
      String version, String from, String to);
  Future<bool> directoryExists(String path);
  Future<bool> fileExists(String path);
  List<String> getAvailableVersions(String versionsPath);
  String get programDirectory;
  String get phpVersionsPath;
  String get localPath;
  String get currentDirectory;
  String getHomeDirectory();
  Map<String, String> get currentEnvironment;

  /// Whether the entity at [path] is a symbolic link (without following it).
  ///
  /// Returns `false` when [path] does not exist.
  Future<bool> isSymLink(String path);

  /// Read the target a symbolic link at [path] points to.
  ///
  /// Returns `null` when [path] is not a symlink, does not exist, or cannot
  /// be read. Implementations must NOT follow the link — the raw stored
  /// target is returned. The returned path may be absolute or relative;
  /// callers are responsible for normalisation.
  Future<String?> readSymLinkTarget(String path);

  /// Delete the symbolic link at [path].
  ///
  /// Throws if [path] is not a symbolic link or the deletion fails.
  /// No-op (returns successfully) when [path] does not exist.
  Future<void> deleteSymLink(String path);

  /// Recursively delete the directory at [path].
  ///
  /// Throws on filesystem errors (e.g. file-in-use, permission denied).
  /// No-op (returns successfully) when [path] does not exist.
  Future<void> deleteDirectory(String path);
}
