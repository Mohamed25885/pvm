import '../../lib/src/core/os_manager.dart';

/// Test double for [IOSManager] that provides configurable responses for file
/// existence checks and returns predetermined environment values.
class FakeOSManager implements IOSManager {
  String mockCurrentDirectory = '/mock/project';
  Map<String, bool> fileExistsMap = {};
  Map<String, bool> directoryExistsMap = {};
  bool shouldThrowOnFileExists = false;
  Map<String, String> environment = {};

  @override
  Future<bool> fileExists(String path) async {
    if (shouldThrowOnFileExists) {
      throw Exception('Mock file check failed');
    }
    return fileExistsMap[path] ?? false;
  }

  @override
  Future<bool> directoryExists(String path) async {
    return directoryExistsMap[path] ?? false;
  }

  @override
  String get currentDirectory => mockCurrentDirectory;

  @override
  Map<String, String> get currentEnvironment => environment;

  @override
  String get programDirectory => throw UnimplementedError();

  @override
  String get phpVersionsPath => throw UnimplementedError();

  @override
  String get localPath => throw UnimplementedError();

  @override
  Future<({String from, String to})> createSymLink(
    String version,
    String from,
    String to,
  ) async {
    throw UnimplementedError();
  }

  @override
  List<String> getAvailableVersions(String versionsPath) {
    throw UnimplementedError();
  }

  @override
  String getHomeDirectory() {
    throw UnimplementedError();
  }

  void setFileExists(String path, bool exists) {
    fileExistsMap[path] = exists;
  }

  void setDirectoryExists(String path, bool exists) {
    directoryExistsMap[path] = exists;
  }
}
