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

abstract class IProcessManager {
  Future<int> runPhp(List<String> args, String phpPath);
  Future<({int pid, int exitCode})> startProcess(
      String executable, List<String> args);
  Future<void> killProcessTree(int pid);
}
