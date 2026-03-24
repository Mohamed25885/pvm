abstract class IOSManager {
  Future<({String from, String to})> createSymLink(
      String version, String from, String to);
  Future<bool> directoryExists(String path);
  Future<bool> fileExists(String path);
  List<String> getAvailableVersions(String versionsPath);
  String get programDirectory;
  String get phpVersionsPath;
  String get localPath;
  String getHomeDirectory();
}
