import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/console.dart';
import '../../core/php_layout.dart';
import '../../core/platform_info.dart';
import '../../domain/exceptions/extension_unavailable_exception.dart';
import '../../domain/php_release.dart';
import '../../interfaces/i_installer.dart';
import '../installation/artifact_installer.dart';

export '../../domain/exceptions/extension_unavailable_exception.dart';
export '../../domain/exceptions/slot_broken_exception.dart';

/// Download and unzip for PECL routes, through [ArtifactInstaller]'s guarded
/// https path, limited to the PECL hosts.
class PeclDownloads {
  final ArtifactInstaller _artifacts;

  PeclDownloads(
    PlatformInfo platform,
    Console console,
    http.Client client,
    Duration retryDelay,
  ) : _artifacts = ArtifactInstaller(
        versionsPath: '', // download/extract only; never installs a slot
        layout: PhpLayout.unix,
        platform: platform,
        allowedHosts: const ['pecl.php.net', 'downloads.php.net'],
        console: console,
        client: client,
        retryDelay: retryDelay,
      );

  static final _version = RegExp(r'^[0-9A-Za-z.\-]+$');

  /// The latest stable version of [ext] from PECL, validated (remote input
  /// that becomes URL and path segments).
  Future<String> stableVersion(String ext, String dir) async {
    final File f;
    try {
      f = await get('https://pecl.php.net/rest/r/$ext/stable.txt', dir);
    } on DownloadException catch (e) {
      if (e.statusCode == 404) {
        throw ExtensionUnavailableException('$ext has no stable PECL release');
      }
      rethrow;
    }
    final v = (await f.readAsString()).trim();
    if (!_version.hasMatch(v) || v.contains('..')) {
      throw Exception('PECL returned an invalid version for $ext: "$v"');
    }
    return v;
  }

  Future<File> get(String url, String dir) => _artifacts.download(
    PhpRelease(
      versionString: p.url.basename(url),
      major: 0,
      minor: 0,
      architecture: Architecture.x64,
      buildType: BuildType.nts,
      downloadUrl: url,
      sha256: '',
      sizeBytes: 0,
      lastModified: DateTime.fromMillisecondsSinceEpoch(0),
    ),
    dir,
  );

  Future<String> sha256Of(File f) => _artifacts.sha256Of(f);

  Future<void> extractZip(String zip, String dest) =>
      _artifacts.extractZip(zip, dest);

  void dispose() => _artifacts.dispose();
}
