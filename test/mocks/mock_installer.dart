import 'dart:io';
import 'package:pvm/src/domain/php_release.dart';
import 'package:pvm/src/interfaces/i_installer.dart';

/// Mock installer for testing.
class MockInstaller implements IInstaller {
  @override
  String get versionsPath => 'C:\\pvm\\versions';

  final preInstallCalls = <String>[];
  final onInstallingCalls = <(String, double)>[];
  final postInstallCalls = <String>[];
  final onInstallFailedCalls = <(String, Exception)>[];

  @override
  Future<void> preInstall(String version) async {
    preInstallCalls.add(version);
  }

  @override
  Future<void> onInstalling(String version, double progress) async {
    onInstallingCalls.add((version, progress));
  }

  @override
  Future<void> postInstall(String version) async {
    postInstallCalls.add(version);
  }

  @override
  Future<void> onInstallFailed(String version, Exception error) async {
    onInstallFailedCalls.add((version, error));
  }

  @override
  Future<void> install(String version, {InstallOptions? options}) async {}

  @override
  Future<bool> isInstalled(String version) async => false;

  @override
  String get installationType => 'mock';

  @override
  Future<File> downloadPhp(
    PhpRelease release,
    String destDir, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    return File('$destDir/mock.zip');
  }

  @override
  Future<bool> verifySha256(File file, String expectedHash) async => true;

  @override
  Future<void> dispose() async {}
}
