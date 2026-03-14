import '../core/os_manager.dart';

class MockOSManager implements IOSManager {
  bool shouldThrowOnSymlink = false;
  bool shouldThrowOnDirectoryExists = false;
  bool shouldThrowOnFileExists = false;
  bool shouldThrowOnGetHomeDirectory = false;
  bool shouldThrowOnGetAvailableVersions = false;
  
  List<String> mockVersions = ['8.0', '8.2'];
  String mockProgramDir = '/mock/pvm';
  String mockLocalPath = '/mock/project/.pvm';
  String mockHomeDir = '/mock/home';
  
  String? symlinkErrorMessage;
  String? directoryExistsErrorMessage;
  String? fileExistsErrorMessage;
  String? getHomeDirectoryErrorMessage;
  String? getAvailableVersionsErrorMessage;
  
  final Map<String, bool> _directoryExistsCache = {};
  final Map<String, bool> _fileExistsCache = {};
  
  int symlinkCallCount = 0;
  int directoryExistsCallCount = 0;
  int fileExistsCallCount = 0;
  int getAvailableVersionsCallCount = 0;
  int getHomeDirectoryCallCount = 0;
  
  final List<({String version, String from, String to})> createdSymlinks = [];

  void resetCallCounts() {
    symlinkCallCount = 0;
    directoryExistsCallCount = 0;
    fileExistsCallCount = 0;
    getAvailableVersionsCallCount = 0;
    getHomeDirectoryCallCount = 0;
  }

  void reset() {
    shouldThrowOnSymlink = false;
    shouldThrowOnDirectoryExists = false;
    shouldThrowOnFileExists = false;
    shouldThrowOnGetHomeDirectory = false;
    shouldThrowOnGetAvailableVersions = false;
    
    symlinkErrorMessage = null;
    directoryExistsErrorMessage = null;
    fileExistsErrorMessage = null;
    getHomeDirectoryErrorMessage = null;
    getAvailableVersionsErrorMessage = null;
    
    _directoryExistsCache.clear();
    _fileExistsCache.clear();
    
    mockVersions = [];
    createdSymlinks.clear();
    resetCallCounts();
  }

  void setDirectoryExistsResult(String path, bool exists) {
    _directoryExistsCache[path] = exists;
  }

  void setFileExistsResult(String path, bool exists) {
    _fileExistsCache[path] = exists;
  }

  @override
  String get programDirectory => mockProgramDir;

  @override
  String get phpVersionsPath => '$mockProgramDir/versions';

  @override
  String get localPath => mockLocalPath;

  @override
  Future<({String from, String to})> createSymLink(
      String version, String from, String to) async {
    symlinkCallCount++;
    
    if (shouldThrowOnSymlink) {
      throw Exception(symlinkErrorMessage ?? 'Mock: Failed to create symlink');
    }
    
    createdSymlinks.add((version: version, from: from, to: to));
    return (from: from, to: to);
  }

  @override
  Future<bool> directoryExists(String path) async {
    directoryExistsCallCount++;
    
    if (shouldThrowOnDirectoryExists) {
      throw Exception(directoryExistsErrorMessage ?? 'Mock: Directory check failed');
    }
    
    if (_directoryExistsCache.containsKey(path)) {
      return _directoryExistsCache[path]!;
    }
    
    return !path.contains('nonexistent');
  }

  @override
  Future<bool> fileExists(String path) async {
    fileExistsCallCount++;
    
    if (shouldThrowOnFileExists) {
      throw Exception(fileExistsErrorMessage ?? 'Mock: File check failed');
    }
    
    if (_fileExistsCache.containsKey(path)) {
      return _fileExistsCache[path]!;
    }
    
    return path.contains('php.exe');
  }

  @override
  List<String> getAvailableVersions(String versionsPath) {
    getAvailableVersionsCallCount++;
    
    if (shouldThrowOnGetAvailableVersions) {
      throw Exception(getAvailableVersionsErrorMessage ?? 'Mock: Failed to get available versions');
    }
    
    return mockVersions;
  }

  @override
  String getHomeDirectory() {
    getHomeDirectoryCallCount++;
    
    if (shouldThrowOnGetHomeDirectory) {
      throw Exception(getHomeDirectoryErrorMessage ?? 'Mock: Failed to get home directory');
    }
    
    return mockHomeDir;
  }
}

class MockProcessManager implements IProcessManager {
  bool shouldThrowOnRun = false;
  bool shouldThrowOnStart = false;
  bool shouldThrowOnKill = false;
  int mockExitCode = 0;
  int mockPid = 12345;
  
  String? runErrorMessage;
  String? startErrorMessage;
  String? killErrorMessage;
  
  int runCallCount = 0;
  int startCallCount = 0;
  int killCallCount = 0;
  
  final List<({List<String> args, String phpPath})> runCalls = [];
  final List<({String executable, List<String> args})> startCalls = [];
  final List<int> killedPids = [];

  void resetCallCounts() {
    runCallCount = 0;
    startCallCount = 0;
    killCallCount = 0;
  }

  void reset() {
    shouldThrowOnRun = false;
    shouldThrowOnStart = false;
    shouldThrowOnKill = false;
    
    runErrorMessage = null;
    startErrorMessage = null;
    killErrorMessage = null;
    
    runCalls.clear();
    startCalls.clear();
    killedPids.clear();
    
    resetCallCounts();
  }

  @override
  Future<int> runPhp(List<String> args, String phpPath) async {
    runCallCount++;
    runCalls.add((args: args, phpPath: phpPath));
    
    if (shouldThrowOnRun) {
      throw Exception(runErrorMessage ?? 'Mock: Failed to run PHP');
    }
    return mockExitCode;
  }

  @override
  Future<({int pid, int exitCode})> startProcess(
      String executable, List<String> args) async {
    startCallCount++;
    startCalls.add((executable: executable, args: args));
    
    if (shouldThrowOnStart) {
      throw Exception(startErrorMessage ?? 'Mock: Failed to start process');
    }
    return (pid: mockPid, exitCode: mockExitCode);
  }

  @override
  Future<void> killProcessTree(int pid) async {
    killCallCount++;
    killedPids.add(pid);
    
    if (shouldThrowOnKill) {
      throw Exception(killErrorMessage ?? 'Mock: Failed to kill process tree');
    }
  }
}
