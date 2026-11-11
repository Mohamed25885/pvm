import 'package:test/test.dart';

import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/domain/php_release.dart';
import 'package:pvm/src/services/release_fetcher.dart';
import 'package:pvm/src/services/release_fetcher_factory.dart';
import 'package:pvm/src/services/windows_release_fetcher.dart';

void main() {
  group('WindowsReleaseFetcher', () {
    test('platformName returns Windows', () {
      final fetcher = WindowsReleaseFetcher();
      expect(fetcher.platformName, 'Windows');
    });

    test('fetchReleases returns releases (uses hardcoded fallback)', () async {
      final fetcher = WindowsReleaseFetcher();
      final releases = await fetcher.fetchReleases();

      expect(releases.length, greaterThan(0));
      expect(releases.first.major, greaterThanOrEqualTo(7));
    });

    test('fetchReleases includes multiple versions', () async {
      final fetcher = WindowsReleaseFetcher();
      final releases = await fetcher.fetchReleases();

      final versions = releases.map((r) => r.major).toSet();
      expect(versions, isNotEmpty);
    });
  });

  group('Linux/macOS release fetcher', () {
    for (final platform in [LinuxPlatformInfo(), MacOSPlatformInfo()]) {
      test('${platform.osType}: list-remote is not offered yet', () {
        expect(
          () => createReleaseFetcher(platform).fetchReleases(),
          throwsA(isA<ReleaseFetcherException>()),
        );
      });
    }
  });

  group('createReleaseFetcher', () {
    test('returns IReleaseFetcher', () {
      // On Windows, should return WindowsReleaseFetcher
      final fetcher = createReleaseFetcher();
      expect(fetcher, isA<IReleaseFetcher>());
    });
  });

  group('IReleaseFetcher interface', () {
    test('windows fetcher can fetch releases', () async {
      final fetcher = WindowsReleaseFetcher();
      final releases = await fetcher.fetchReleases();
      expect(releases, isA<List<PhpRelease>>());
    });
  });
}
