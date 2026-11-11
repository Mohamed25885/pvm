import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../domain/php_release.dart';
import '../domain/php_version.dart';
import '../interfaces/i_installer.dart';
import '../interfaces/i_release_source.dart';
import 'https_get.dart';
import 'release_fetcher.dart';

/// static-php.dev `bulk` CLI builds for Linux/macOS (single static `php`
/// binary in a `.tar.gz`). Only builds whose `.sha256` sidecar is listed are
/// offered, so every release carries a published checksum (Q1). The builds
/// are NTS; the requested build type is ignored.
class StaticPhpReleaseSource implements IReleaseSource {
  final http.Client _client;

  /// `linux` or `macos`, as used in the static-php file names.
  final String os;

  StaticPhpReleaseSource({required this._client, required this.os});

  static final _entry = RegExp(
    r'href="(?:/v3/php-bin/bulk/)?'
    r'(php-(\d{1,4})\.(\d{1,4})\.(\d{1,4})-cli-([a-z]+)-(x86_64|aarch64)\.tar\.gz)"',
  );

  @override
  String get name => 'dl.static-php.dev';

  @override
  Future<PhpRelease> resolve(
    PhpVersion version, {
    required Architecture architecture,
    required BuildType buildType,
  }) async {
    final arch = switch (architecture) {
      Architecture.x64 => 'x86_64',
      Architecture.arm64 => 'aarch64',
      Architecture.x86 => throw NoMatchingReleaseException(
        'static-php.dev has no x86 (32-bit) builds',
      ),
    };

    final html = await _get(PvmUrls.staticPhpBulk);
    final names = RegExp(
      r'href="(?:/v3/php-bin/bulk/)?([^"/]+)"',
    ).allMatches(html).map((m) => m.group(1)!).toSet();

    final builds = <({int patch, String file})>[];
    for (final m in _entry.allMatches(html)) {
      if (int.parse(m.group(2)!) != version.major ||
          int.parse(m.group(3)!) != version.minor ||
          m.group(5) != os ||
          m.group(6) != arch ||
          !names.contains('${m.group(1)}.sha256')) {
        continue;
      }
      builds.add((patch: int.parse(m.group(4)!), file: m.group(1)!));
    }
    builds.sort((a, b) => b.patch.compareTo(a.patch));

    final match = version.hasPatch
        ? builds.where((b) => b.patch == version.patch).firstOrNull
        : builds.firstOrNull;
    if (match == null) {
      final available = builds.map((b) => '${version.slot}.${b.patch}');
      throw NoMatchingReleaseException(
        'No static-php build for PHP $version ($os-$arch). '
        '${available.isEmpty ? 'None available for ${version.slot}.' : 'Available: ${available.join(', ')}'}',
      );
    }

    final url = '${PvmUrls.staticPhpBulk}${match.file}';
    final sidecar = await _get('$url.sha256');
    final sha = sidecar.trim().split(RegExp(r'\s+')).first;
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha)) {
      throw ReleaseFetcherException('Malformed checksum at $url.sha256');
    }

    final resolved = '${version.slot}.${match.patch}';
    // Remote data becomes a directory name: re-validate (path traversal).
    PhpVersion.parse(resolved);
    return PhpRelease(
      versionString: resolved,
      major: version.major,
      minor: version.minor,
      patch: match.patch,
      architecture: architecture,
      buildType: BuildType.nts,
      downloadUrl: url,
      sha256: sha.toLowerCase(),
      sizeBytes: 0,
      lastModified: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Future<String> _get(String url) async {
    final http.Response response;
    try {
      // url is always under PvmUrls.staticPhpBulk; later hops must be https.
      response = await http.Response.fromStream(
        await httpsGet(_client, Uri.parse(url)),
      ).timeout(const Duration(seconds: 60));
    } catch (e) {
      throw ReleaseFetcherException('Could not reach $url: $e');
    }
    if (response.statusCode != 200) {
      throw ReleaseFetcherException(
        '$url returned HTTP ${response.statusCode}',
      );
    }
    return response.body;
  }
}
