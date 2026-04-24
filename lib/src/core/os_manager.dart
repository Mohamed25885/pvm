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
}
