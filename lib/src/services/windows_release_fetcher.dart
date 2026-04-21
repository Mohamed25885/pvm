import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/php_release.dart';
import 'release_fetcher.dart';

class WindowsReleaseFetcher implements IReleaseFetcher {
  static const String _apiUrl =
      'https://downloads.php.net/~windows/releases/releases.json';

  @override
  String get platformName => 'Windows';

  @override
  Future<List<PhpRelease>> fetchReleases() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode != 200) {
        return _getHardcodedReleases();
      }
      final parsed = _parseReleasesJson(response.body);
      if (parsed.isEmpty) {
        return _getHardcodedReleases();
      }
      return parsed;
    } catch (e) {
      return _getHardcodedReleases();
    }
  }

  List<PhpRelease> _parseReleasesJson(String json) {
    final List<PhpRelease> releases = [];
    final data = jsonDecode(json) as Map<String, dynamic>;

    for (final entry in data.entries) {
      final versionKey = entry.key;
      final versionData = entry.value as Map<String, dynamic>;

      final version = versionData['version'] as String?;
      if (version == null) continue;

      final parts = versionKey.split('.');
      if (parts.length < 2) continue;

      final major = int.tryParse(parts[0]);
      final minor = int.tryParse(parts[1]);
      if (major == null || minor == null) continue;

      int? patch;
      final patchMatch = RegExp(r'(\d+)$').firstMatch(version);
      if (patchMatch != null) {
        patch = int.tryParse(patchMatch.group(1)!);
      }

      for (final buildEntry in versionData.entries) {
        final buildKey = buildEntry.key;
        final buildInfo = buildEntry.value as Map<String, dynamic>;

        // Skip non-build fields
        if (buildKey == 'version' ||
            buildKey == 'source' ||
            buildKey == 'test_pack') {
          continue;
        }

        final arch = _parseArchitecture(buildKey);
        if (arch == null) continue;

        final buildType = _parseBuildType(buildKey);
        if (buildType == null) continue;

        final zip = buildInfo['zip'] as Map<String, dynamic>?;
        if (zip == null) continue;

        final path = zip['path'] as String?;
        if (path == null) continue;

        final size = _parseSize(zip['size'] as String?);
        final sha256 = zip['sha256'] as String? ?? '';
        final mtime = buildInfo['mtime'] as String?;

        DateTime? lastModified;
        if (mtime != null) {
          lastModified = DateTime.tryParse(mtime);
        }

        releases.add(PhpRelease(
          versionString: version,
          major: major,
          minor: minor,
          patch: patch,
          architecture: arch,
          buildType: buildType,
          downloadUrl: 'https://downloads.php.net/~windows/releases/$path',
          sha256: sha256,
          sizeBytes: size,
          lastModified: lastModified ?? DateTime.now(),
        ));
      }
    }

    // Sort by version descending
    releases.sort((a, b) {
      final aVer = a.major * 100 + a.minor * 10 + (a.patch ?? 0);
      final bVer = b.major * 100 + b.minor * 10 + (b.patch ?? 0);
      return bVer.compareTo(aVer);
    });

    return releases;
  }

  Architecture? _parseArchitecture(String buildKey) {
    final lower = buildKey.toLowerCase();
    if (lower.contains('x64') ||
        lower.contains('x86_64') ||
        lower.contains('amd64')) {
      return Architecture.x64;
    }
    if (lower.contains('x86') && !lower.contains('x86_64')) {
      return Architecture.x86;
    }
    return null;
  }

  BuildType? _parseBuildType(String buildKey) {
    final lower = buildKey.toLowerCase();
    if (lower.contains('nts')) {
      return BuildType.nts;
    }
    if (lower.contains('ts')) {
      return BuildType.ts;
    }
    return null;
  }

  int _parseSize(String? sizeStr) {
    if (sizeStr == null) return 0;
    // Parse "25.02MB" or similar
    final match = RegExp(r'([\d.]+)\s*(MB|GB)?').firstMatch(sizeStr);
    if (match == null) return 0;

    final num part = double.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)?.toUpperCase();

    if (unit == 'GB') {
      return (part * 1024 * 1024 * 1024).round();
    }
    return (part * 1024 * 1024).round();
  }

  List<PhpRelease> _getHardcodedReleases() {
    final now = DateTime.now();
    return [
      // PHP 8.5
      PhpRelease(
          versionString: '8.5.5',
          major: 8,
          minor: 5,
          patch: 5,
          architecture: Architecture.x64,
          buildType: BuildType.nts,
          downloadUrl:
              'https://downloads.php.net/~windows/releases/php-8.5.5-nts-Win32-vs17-x64.zip',
          sha256:
              '107f64f689eec2a0966b4d8a42f0e34e8dfa04c5097c9548e35fb951cba0a464',
          sizeBytes: 35000000,
          lastModified: now),
      PhpRelease(
          versionString: '8.5.5',
          major: 8,
          minor: 5,
          patch: 5,
          architecture: Architecture.x64,
          buildType: BuildType.ts,
          downloadUrl:
              'https://downloads.php.net/~windows/releases/php-8.5.5-Win32-vs17-x64.zip',
          sha256:
              'b4099a15cd3fc797d007282fff793ebbd65127cb2a9caf5c7eb9254c30b95098',
          sizeBytes: 35300000,
          lastModified: now),
      // PHP 8.4
      PhpRelease(
          versionString: '8.4.20',
          major: 8,
          minor: 4,
          patch: 20,
          architecture: Architecture.x64,
          buildType: BuildType.nts,
          downloadUrl:
              'https://downloads.php.net/~windows/releases/php-8.4.20-nts-Win32-vs17-x64.zip',
          sha256:
              'bac1a970a676e8d875d5d39fc5ff388f231fadb9fb051b77b17db06a657673df',
          sizeBytes: 34000000,
          lastModified: now),
      PhpRelease(
          versionString: '8.4.20',
          major: 8,
          minor: 4,
          patch: 20,
          architecture: Architecture.x64,
          buildType: BuildType.ts,
          downloadUrl:
              'https://downloads.php.net/~windows/releases/php-8.4.20-Win32-vs17-x64.zip',
          sha256:
              '11f211a3a657962071f967f7e8f2dc1cfc379168093f6bc1d3cd0071eb47e178',
          sizeBytes: 34300000,
          lastModified: now),
      // PHP 8.3
      PhpRelease(
          versionString: '8.3.30',
          major: 8,
          minor: 3,
          patch: 30,
          architecture: Architecture.x64,
          buildType: BuildType.nts,
          downloadUrl:
              'https://downloads.php.net/~windows/releases/php-8.3.30-nts-Win32-vs16-x64.zip',
          sha256:
              '42637b42b38b9c0d731e59c5cb8b755693a01b110cd2f31951f67de5cb4cd129',
          sizeBytes: 32000000,
          lastModified: now),
      PhpRelease(
          versionString: '8.3.30',
          major: 8,
          minor: 3,
          patch: 30,
          architecture: Architecture.x64,
          buildType: BuildType.ts,
          downloadUrl:
              'https://downloads.php.net/~windows/releases/php-8.3.30-Win32-vs16-x64.zip',
          sha256:
              '606c69912d7a1fbd9215ad5b6941e081d0cc12fce7f00b95d612da032244f45f',
          sizeBytes: 32300000,
          lastModified: now),
      // PHP 8.2
      PhpRelease(
          versionString: '8.2.30',
          major: 8,
          minor: 2,
          patch: 30,
          architecture: Architecture.x64,
          buildType: BuildType.nts,
          downloadUrl:
              'https://downloads.php.net/~windows/releases/php-8.2.30-nts-Win32-vs16-x64.zip',
          sha256:
              '8a6e409adb5f7fb196c07315c69195c4eb87eec8acae2e74a0e04ec50745a055',
          sizeBytes: 30000000,
          lastModified: now),
    ];
  }
}
