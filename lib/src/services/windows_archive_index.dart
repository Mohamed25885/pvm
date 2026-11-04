import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../domain/php_release.dart';
import 'release_fetcher.dart';

/// Lists archived (older patch) Windows builds from the windows.php.net
/// archive directory.
///
/// `releases.json` only carries the latest patch of each minor; older patches
/// live under `releases/archives/`, which publishes **no checksums**. Releases
/// returned here therefore have an empty [PhpRelease.sha256] and must only be
/// installed with an explicit opt-in.
class WindowsArchiveIndex {
  final http.Client _client;
  final String listingUrl;

  WindowsArchiveIndex({
    http.Client? client,
    this.listingUrl = PvmUrls.windowsArchivesListing,
  }) : _client = client ?? http.Client();

  static final _entry = RegExp(
    // Optional "-1" etc. after the patch: Windows rebuild suffix (group 8).
    r'href="(php-(\d{1,4})\.(\d{1,4})\.(\d{1,4})(?:-(\d{1,3}))?-(nts-)?Win32-(v[cs]\d+)-(x64|x86)\.zip)"',
  );

  Future<List<PhpRelease>> fetch() async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse(listingUrl))
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw ReleaseFetcherException(
        'Could not reach the PHP archive index ($listingUrl): $e',
      );
    }
    if (response.statusCode != 200) {
      throw ReleaseFetcherException(
        'PHP archive index returned HTTP ${response.statusCode} ($listingUrl)',
      );
    }
    return parse(response.body);
  }

  /// One release per (version, build type, arch); when a rebuild exists
  /// (`8.3.2-1`), the highest rebuild number wins.
  static List<PhpRelease> parse(String html) {
    final best = <String, ({int rebuild, PhpRelease release})>{};
    for (final m in _entry.allMatches(html)) {
      final file = m.group(1)!;
      final major = int.parse(m.group(2)!);
      final minor = int.parse(m.group(3)!);
      final patch = int.parse(m.group(4)!);
      final rebuild = int.tryParse(m.group(5) ?? '') ?? 0;
      final buildType = m.group(6) != null ? BuildType.nts : BuildType.ts;
      final arch = m.group(8) == 'x64' ? Architecture.x64 : Architecture.x86;
      final key = '$major.$minor.$patch/${buildType.name}/${arch.name}';
      final existing = best[key];
      if (existing != null && existing.rebuild >= rebuild) continue;
      best[key] = (
        rebuild: rebuild,
        release: PhpRelease(
          versionString: '$major.$minor.$patch',
          major: major,
          minor: minor,
          patch: patch,
          architecture: arch,
          buildType: buildType,
          downloadUrl: '${PvmUrls.windowsArchivesDownloadBase}$file',
          sha256: '',
          sizeBytes: 0,
          lastModified: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }
    return best.values.map((e) => e.release).toList();
  }
}
