import 'dart:convert';
import '../domain/php_release.dart';
import '../core/constants.dart';

class ReleaseParser {
  static final _versionPrefix = RegExp(
    r'^(\d{1,4})\.(\d{1,4})(?:\.(\d{1,4}))?',
  );

  static List<PhpRelease> parseWindowsReleases(String json) {
    final List<PhpRelease> releases = [];

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;

      for (final entry in data.entries) {
        final versionKey = entry.key;
        final versionData = entry.value as Map<String, dynamic>;

        // Parse version from the version field: "7.4.33" -> 7, 4, 33.
        // Windows rebuilds carry a suffix ("8.4.27-1"); the suffix must not
        // turn the patch into 0 (it did: int.tryParse("27-1") == null).
        final version = versionData['version'] as String?;
        if (version == null) continue;

        final vm = _versionPrefix.firstMatch(version.trim());
        if (vm == null) continue;
        final major = int.parse(vm.group(1)!);
        final minor = int.parse(vm.group(2)!);
        final patch = vm.group(3) != null ? int.parse(vm.group(3)!) : 0;

        // Parse major.minor from versionKey: "7.4" -> 7.4
        final versionKeyParts = versionKey.split('.');
        if (versionKeyParts.length < 2) continue;

        // Determine architecture and build type from architecture keys in versionData
        // Look for keys like "ts-vc15-x64", "nts-vs16-x86"
        Architecture? architecture;
        BuildType? buildType;
        String? downloadUrl;
        int sizeBytes = 0;

        for (final archKey in versionData.keys) {
          // Skip non-architecture keys
          if (archKey == 'version' ||
              archKey == 'source' ||
              archKey == 'test_pack') {
            continue;
          }

          // Parse architecture key: "ts-vc15-x64", "nts-vs16-x86"
          final isX64 = archKey.contains('x64');
          final isTS = archKey.startsWith('ts-');

          architecture = isX64 ? Architecture.x64 : Architecture.x86;
          buildType = isTS ? BuildType.ts : BuildType.nts;

          // Get the architecture-specific data
          final archData = versionData[archKey] as Map<String, dynamic>?;
          if (archData == null) continue;

          // Get the zip file info
          final zipData = archData['zip'] as Map<String, dynamic>?;
          if (zipData == null) continue;

          // Get download path and size
          final path = zipData['path'] as String?;
          final sizeStr = zipData['size'] as String?;

          if (path == null) continue;

          downloadUrl = '${PvmUrls.windowsDownloadBase}$path';

          // Parse size: "25.02MB" -> bytes
          if (sizeStr != null) {
            sizeBytes = _parseSize(sizeStr);
          }

          releases.add(
            PhpRelease(
              versionString: version,
              major: major,
              minor: minor,
              patch: patch,
              architecture: architecture,
              buildType: buildType,
              downloadUrl: downloadUrl,
              sha256: zipData['sha256'] as String? ?? '',
              sizeBytes: sizeBytes,
              lastModified: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      // Return empty on parse error
    }

    return releases;
  }

  static int _parseSize(String sizeStr) {
    // Parse size string like "25.02MB" to bytes
    final match = RegExp(
      r'([\d.]+)\s*(MB|GB|KB)?',
      caseSensitive: false,
    ).firstMatch(sizeStr);
    if (match == null) return 0;

    final value = double.tryParse(match.group(1)!) ?? 0;
    final unit = (match.group(2) ?? 'MB').toUpperCase();

    switch (unit) {
      case 'GB':
        return (value * 1024 * 1024 * 1024).round();
      case 'MB':
        return (value * 1024 * 1024).round();
      case 'KB':
        return (value * 1024).round();
      default:
        return value.round();
    }
  }
}
