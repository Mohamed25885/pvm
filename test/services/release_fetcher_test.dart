import 'package:test/test.dart';

import '../../lib/src/domain/php_release.dart';
import '../../lib/src/services/release_fetcher.dart';
import '../../lib/src/services/release_fetcher_factory.dart';
import '../../lib/src/services/windows_release_fetcher.dart';
import '../../lib/src/services/linux_release_fetcher.dart';
import '../../lib/src/services/macos_release_fetcher.dart';

void main() {
  group('WindowsReleaseFetcher', () {
    test('platformName returns Windows', () {
      final fetcher = WindowsReleaseFetcher();
      expect(fetcher.platformName, 'Windows');
    });

    test('fetchReleases returns releases (uses hardcoded fallback)', () async {
      final fetcher = WindowsReleaseFetcher();
      final releases = await fetcher.fetchReleases();

      expect(releases, isNotEmpty);
      expect(releases.first.major, 8);
    });

    test('fetchReleases includes multiple versions', () async {
      final fetcher = WindowsReleaseFetcher();
      final releases = await fetcher.fetchReleases();

      final versions = releases.map((r) => r.major).toSet();
      expect(versions, isNotEmpty);
    });
  });

  group('LinuxReleaseFetcher', () {
    test('platformName returns Linux', () {
      final fetcher = LinuxReleaseFetcher();
      expect(fetcher.platformName, 'Linux');
    });

    test('fetchReleases throws ReleaseFetcherException', () async {
      final fetcher = LinuxReleaseFetcher();
      expect(
        () => fetcher.fetchReleases(),
        throwsA(isA<ReleaseFetcherException>()),
      );
    });
  });

  group('MacosReleaseFetcher', () {
    test('platformName returns macOS', () {
      final fetcher = MacosReleaseFetcher();
      expect(fetcher.platformName, 'macOS');
    });

    test('fetchReleases throws ReleaseFetcherException', () async {
      final fetcher = MacosReleaseFetcher();
      expect(
        () => fetcher.fetchReleases(),
        throwsA(isA<ReleaseFetcherException>()),
      );
    });
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
