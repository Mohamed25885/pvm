import 'dart:io';

import '../core/process_manager.dart';
import '../domain/php_release.dart';
import '../interfaces/i_installer.dart';

abstract class PackageManagerInstaller implements IInstaller {
  final String _versionsPath;
  final IProcessManager processManager;

  PackageManagerInstaller({
    required String versionsPath,
    required this.processManager,
  }) : _versionsPath = versionsPath;

  @override
  String get versionsPath => _versionsPath;

  @override
  Future<bool> isInstalled(String version) async {
    final versionResult = await processManager.runCaptured(
      ProcessSpec(executable: 'php', arguments: ['-r', 'echo PHP_VERSION;']),
    );
    if (versionResult.exitCode != 0) return false;

    final installedVersion = versionResult.stdout.trim();
    return _matchesRequestedVersion(installedVersion, version);
  }

  bool _matchesRequestedVersion(String installed, String requested) {
    // Same major.minor (and patch, when requested) - never just same major.
    final want = requested.split('.');
    final have = installed.split('.');
    if (have.length < want.length) return false;
    for (var i = 0; i < want.length; i++) {
      if (have[i] != want[i]) return false;
    }
    return true;
  }

  @override
  Future<InstallResult> install(
    String version, {
    InstallOptions? options,
  }) async {
    throw UnimplementedError('Package managers implement this directly');
  }

  @override
  Future<File> downloadPhp(
    PhpRelease release,
    String destDir, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    throw UnimplementedError(
      '$runtimeType uses a package manager, not downloads',
    );
  }

  @override
  Future<bool> verifySha256(File file, String expectedHash) async => true;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> preInstall(String version) async {}

  @override
  Future<void> onInstalling(String version, double progress) async {}

  @override
  Future<void> postInstall(String version) async {}

  @override
  Future<void> onInstallFailed(String version, Exception error) async {}
}
