import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/console.dart';
import '../core/php_layout.dart';
import '../core/platform_info.dart';
import '../domain/install_record.dart';
import '../domain/php_release.dart';
import '../domain/php_version.dart';
import '../interfaces/i_installer.dart';
import '../interfaces/i_release_source.dart';
import '../services/folder_probe.dart';
import '../services/installation/artifact_installer.dart';
import '../services/release_fetcher.dart';
import '../services/windows_archive_index.dart';
import '../services/windows_release_source.dart';

/// Windows: windows.php.net ZIPs, installed through the shared transactional
/// [ArtifactInstaller] pipeline. Release lookup is a [WindowsReleaseSource].
class WindowsInstaller implements IInstaller {
  final IReleaseSource _source;
  final ArtifactInstaller _artifacts;

  WindowsInstaller({
    required String versionsPath,
    required IReleaseFetcher releaseFetcher,
    required Console console,
    http.Client? client,
    Duration retryDelay = const Duration(seconds: 1),
    WindowsArchiveIndex? archiveIndex,
    FolderProbe? probe,
  }) : _source = WindowsReleaseSource(
         fetcher: releaseFetcher,
         archiveIndex: archiveIndex,
         console: console,
       ),
       _artifacts = ArtifactInstaller(
         versionsPath: versionsPath,
         layout: PhpLayout.windows,
         platform: WindowsPlatformInfo(),
         allowedHosts: allowedDomains,
         console: console,
         probe: probe,
         client: client,
         retryDelay: retryDelay,
       );

  static const List<String> allowedDomains = [
    'windows.php.net',
    'downloads.php.net',
  ];

  @override
  String get versionsPath => _artifacts.versionsPath;

  @override
  String get installationType => 'ZIP extraction';

  @override
  Future<bool> isInstalled(String version) => _artifacts.isInstalled(version);

  @override
  Future<InstallResult> install(
    String version, {
    InstallOptions? options,
  }) async {
    // Validate before the value is used in any path (path traversal guard).
    final requested = PhpVersion.parse(version);
    final release = await _source.resolve(
      requested,
      architecture: options?.architecture ?? Architecture.x64,
      buildType: options?.buildType ?? BuildType.nts,
    );
    final resolved = release.displayVersion;

    if (await _artifacts.slotHolds(
          resolved,
          replace: options?.update != null,
        ) &&
        !(options?.force ?? false)) {
      return InstallResult(resolved, alreadyInstalled: true);
    }

    await preInstall(resolved);
    try {
      await _artifacts.install(
        release,
        resolved,
        kind: SlotKind.windowsZip,
        allowUnverified: options?.allowUnverified ?? false,
        beforeSwap: options?.update,
      );
    } on Exception catch (e) {
      await onInstallFailed(resolved, e);
      rethrow;
    }
    await postInstall(resolved);
    return InstallResult(resolved);
  }

  Future<String> sha256Of(File file) => _artifacts.sha256Of(file);

  /// Extracts [zipPath] into [destPath] with the zip-slip guard.
  Future<void> extractZip(String zipPath, String destPath) =>
      _artifacts.extractZip(zipPath, destPath);

  @override
  Future<File> downloadPhp(
    PhpRelease release,
    String destDir, {
    void Function(DownloadProgress)? onProgress,
  }) => _artifacts.download(release, destDir, onProgress: onProgress);

  @override
  Future<bool> verifySha256(File file, String expectedHash) =>
      _artifacts.verifySha256(file, expectedHash);

  @override
  Future<void> dispose() async => _artifacts.dispose();

  @override
  Future<void> preInstall(String version) async {}

  @override
  Future<void> onInstalling(String version, double progress) async {}

  @override
  Future<void> postInstall(String version) async {}

  @override
  Future<void> onInstallFailed(String version, Exception error) async {}
}
