import 'os_manager.dart';
import '../services/privilege_escalation_service.dart';

/// Decorator that retries [IOSManager.createSymLink] after optional elevation.
class ElevatingOSManager implements IOSManager {
  final IOSManager _delegate;
  final PrivilegeEscalationService _escalation;

  ElevatingOSManager(this._delegate, this._escalation);

  @override
  Future<({String from, String to})> createSymLink(
    String version,
    String from,
    String to,
  ) {
    return _escalation.runWithElevationRetry(
      () => _delegate.createSymLink(version, from, to),
    );
  }

  @override
  Future<bool> directoryExists(String path) => _delegate.directoryExists(path);

  @override
  Future<bool> fileExists(String path) => _delegate.fileExists(path);

  @override
  List<String> getAvailableVersions(String versionsPath) =>
      _delegate.getAvailableVersions(versionsPath);

  @override
  String get programDirectory => _delegate.programDirectory;

  @override
  String get phpVersionsPath => _delegate.phpVersionsPath;

  @override
  String get localPath => _delegate.localPath;

  @override
  String get currentDirectory => _delegate.currentDirectory;

  @override
  String getHomeDirectory() => _delegate.getHomeDirectory();

  @override
  Map<String, String> get currentEnvironment => _delegate.currentEnvironment;

  @override
  Future<bool> isSymLink(String path) => _delegate.isSymLink(path);

  @override
  Future<String?> readSymLinkTarget(String path) =>
      _delegate.readSymLinkTarget(path);

  @override
  Future<void> deleteSymLink(String path) => _delegate.deleteSymLink(path);

  @override
  Future<void> deleteDirectory(String path) => _delegate.deleteDirectory(path);
}
