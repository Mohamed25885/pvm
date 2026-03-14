import '../interfaces/os_manager.dart';

class MockOSManager implements IOSManager {
  bool shouldThrowOnSymlink = false;
  bool shouldThrowOnDirectoryExists = false;
  bool shouldThrowOnFileExists = false;
  List<String> mockVersions = ['8.0', '8.2'];
  String mockProgramDir = '/mock/pvm';
  String mockLocalPath = '/mock/project/.pvm';
  String mockHomeDir = '/mock/home';

  @override
  String get programDirectory => mockProgramDir;

  @override
  String get phpVersionsPath => '$mockProgramDir/versions';

  @override
  String get localPath => mockLocalPath;

  @override
  Future<({String from, String to})> createSymLink(
      String version, String from, String to) async {
    if (shouldThrowOnSymlink) {
      throw Exception('Mock: Failed to create symlink');
    }
    return (from: from, to: to);
  }

  @override
  Future<bool> directoryExists(String path) async {
    if (shouldThrowOnDirectoryExists) {
      throw Exception('Mock: Directory check failed');
    }
    return !path.contains('nonexistent');
  }

  @override
  Future<bool> fileExists(String path) async {
    if (shouldThrowOnFileExists) {
      throw Exception('Mock: File check failed');
    }
    return path.contains('php.exe');
  }

  @override
  List<String> getAvailableVersions(String versionsPath) {
    return mockVersions;
  }

  @override
  String getHomeDirectory() => mockHomeDir;
}

class MockProcessManager implements IProcessManager {
  bool shouldThrowOnRun = false;
  bool shouldThrowOnStart = false;
  int mockExitCode = 0;

  @override
  Future<int> runPhp(List<String> args, String phpPath) async {
    if (shouldThrowOnRun) {
      throw Exception('Mock: Failed to run PHP');
    }
    return mockExitCode;
  }

  @override
  Future<({int pid, int exitCode})> startProcess(
      String executable, List<String> args) async {
    if (shouldThrowOnStart) {
      throw Exception('Mock: Failed to start process');
    }
    return (pid: 12345, exitCode: mockExitCode);
  }

  @override
  Future<void> killProcessTree(int pid) async {
    // Mock implementation - does nothing
  }
}
