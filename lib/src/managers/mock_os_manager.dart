import 'dart:io';

import '../core/os_manager.dart';
import '../core/process_manager.dart';

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

  /// Override for createSymLink source directory existence check.
  /// When set, createSymLink uses this value instead of real filesystem check.
  bool? symlinkSourceExistsOverride;

  /// Override for current directory (used by PhpCommand root discovery).
  String? mockCurrentDirectory;

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
    symlinkSourceExistsOverride = null;
    mockCurrentDirectory = null;
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
  String get currentDirectory => mockCurrentDirectory ?? Directory.current.path;

  @override
  Future<({String from, String to})> createSymLink(
      String version, String from, String to) async {
    symlinkCallCount++;

    if (shouldThrowOnSymlink) {
      throw Exception(symlinkErrorMessage ?? 'Mock: Failed to create symlink');
    }

    // Allow tests to override the source directory existence check
    if (symlinkSourceExistsOverride != null) {
      final sourceExists = symlinkSourceExistsOverride!;
      if (!sourceExists) {
        throw Exception('Mock: Source directory does not exist: $from');
      }
    } else {
      // Fall back to real filesystem check
      if (!Directory(from).existsSync()) {
        throw Exception('Mock: Source directory does not exist: $from');
      }
    }

    createdSymlinks.add((version: version, from: from, to: to));
    return (from: from, to: to);
  }

  @override
  Future<bool> directoryExists(String path) async {
    directoryExistsCallCount++;

    if (shouldThrowOnDirectoryExists) {
      throw Exception(
          directoryExistsErrorMessage ?? 'Mock: Directory check failed');
    }

    // Explicit cache takes priority
    if (_directoryExistsCache.containsKey(path)) {
      return _directoryExistsCache[path]!;
    }

    // Override makes all paths return the override value
    if (symlinkSourceExistsOverride != null) {
      return symlinkSourceExistsOverride!;
    }

    // For paths outside the mock directory, check the real filesystem.
    // This handles test-created temp directories.
    if (!path.contains(mockProgramDir)) {
      return Directory(path).existsSync();
    }

    // Default fallback for mock paths: conservative — assume does not exist
    return false;
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

    // For paths outside the mock directory, check the real filesystem.
    // This handles test-created temp directories.
    if (!path.contains(mockProgramDir)) {
      return File(path).existsSync();
    }

    // Default fallback for mock paths: use the php.exe heuristic
    return path.contains('php.exe');
  }

  @override
  List<String> getAvailableVersions(String versionsPath) {
    getAvailableVersionsCallCount++;

    if (shouldThrowOnGetAvailableVersions) {
      throw Exception(getAvailableVersionsErrorMessage ??
          'Mock: Failed to get available versions');
    }

    return mockVersions;
  }

  @override
  String getHomeDirectory() {
    getHomeDirectoryCallCount++;

    if (shouldThrowOnGetHomeDirectory) {
      throw Exception(
          getHomeDirectoryErrorMessage ?? 'Mock: Failed to get home directory');
    }

    return mockHomeDir;
  }
}

class MockProcessManager implements IProcessManager {
  bool shouldThrowOnRunInteractive = false;
  bool shouldThrowOnRunCaptured = false;
  int mockExitCode = 0;
  String mockStdout = '';
  String mockStderr = '';

  String? runInteractiveErrorMessage;
  String? runCapturedErrorMessage;

  int runInteractiveCallCount = 0;
  int runCapturedCallCount = 0;

  final List<ProcessSpec> interactiveCalls = [];
  final List<ProcessSpec> capturedCalls = [];

  void resetCallCounts() {
    runInteractiveCallCount = 0;
    runCapturedCallCount = 0;
  }

  void reset() {
    shouldThrowOnRunInteractive = false;
    shouldThrowOnRunCaptured = false;

    runInteractiveErrorMessage = null;
    runCapturedErrorMessage = null;

    interactiveCalls.clear();
    capturedCalls.clear();

    resetCallCounts();
  }

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    runInteractiveCallCount++;
    interactiveCalls.add(spec);

    if (shouldThrowOnRunInteractive) {
      throw Exception(
        runInteractiveErrorMessage ?? 'Mock: Failed to run interactive process',
      );
    }

    return mockExitCode;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    runCapturedCallCount++;
    capturedCalls.add(spec);

    if (shouldThrowOnRunCaptured) {
      throw Exception(
        runCapturedErrorMessage ?? 'Mock: Failed to run captured process',
      );
    }

    return CapturedProcessResult(
      stdout: mockStdout,
      stderr: mockStderr,
      exitCode: mockExitCode,
    );
  }
}
