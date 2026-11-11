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

/// Linux/macOS: static-php.dev `bulk` builds (a single static `php`),
/// installed through the shared [ArtifactInstaller] pipeline as
/// [SlotKind.static]. The builds are NTS; the requested build type is ignored.
class StaticPhpInstaller implements IInstaller {
  final IReleaseSource _source;
  final ArtifactInstaller _artifacts;

  StaticPhpInstaller({
    required String versionsPath,
    required this._source,
    required PlatformInfo platform,
    required Console console,
    FolderProbe? probe,
    http.Client? client,
    Duration retryDelay = const Duration(seconds: 1),
  }) : _artifacts = ArtifactInstaller(
         versionsPath: versionsPath,
         layout: PhpLayout.unix,
         platform: platform,
         allowedHosts: const ['dl.static-php.dev'],
         console: console,
         probe: probe,
         client: client,
         retryDelay: retryDelay,
       );

  @override
  String get versionsPath => _artifacts.versionsPath;

  @override
  String get installationType => 'static-php build';

  @override
  Future<bool> isInstalled(String version) => _artifacts.isInstalled(version);

  @override
  Future<InstallResult> install(
    String version, {
    InstallOptions? options,
  }) async {
    // Validate before the value is used in any path (path traversal guard).
    final release = await _source.resolve(
      PhpVersion.parse(version),
      architecture: options?.architecture ?? Architecture.x64,
      buildType: BuildType.nts,
    );
    final resolved = release.displayVersion;

    if (await _artifacts.slotHolds(
          resolved,
          SlotKind.static,
          replace: options?.update != null,
          force: options?.force ?? false,
        ) &&
        !(options?.force ?? false)) {
      return InstallResult(resolved, alreadyInstalled: true);
    }
    await _artifacts.install(
      release,
      resolved,
      kind: SlotKind.static,
      allowUnverified: options?.allowUnverified ?? false,
      beforeSwap: options?.update,
    );
    return InstallResult(resolved);
  }

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
