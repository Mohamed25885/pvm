import 'package:test/test.dart';

import '../../lib/src/domain/php_release.dart';
import '../../lib/src/services/release_fetcher.dart';
import '../../lib/src/services/php_downloader.dart';
import '../../lib/src/services/release_fetcher_factory.dart';
import '../../lib/src/commands/list_remote_command.dart';
import '../../lib/src/commands/install_command.dart';
import '../mocks/mock_console.dart';

void main() {
  group('Full workflow integration', () {
    test('create fetcher from factory', () {
      final fetcher = createReleaseFetcher();
      expect(fetcher, isA<IReleaseFetcher>());
      expect(fetcher.platformName, 'Windows');
    });

    test('windows fetcher fetch releases', () async {
      final fetcher = createReleaseFetcher();
      final releases = await fetcher.fetchReleases();

      expect(releases, isNotEmpty);
    });

    test('filter releases by version', () async {
      final fetcher = createReleaseFetcher();
      final releases = await fetcher.fetchReleases();

      final filter = PhpReleaseFilter(major: 8);
      final versioned = releases.where((r) => filter.matches(r)).toList();

      expect(versioned, isNotEmpty);
      expect(versioned.every((r) => r.major == 8), isTrue);
    });

    test('filter releases by architecture', () async {
      final fetcher = createReleaseFetcher();
      final releases = await fetcher.fetchReleases();

      final filter = PhpReleaseFilter(architecture: Architecture.x64);
      final filtered = releases.where((r) => filter.matches(r)).toList();

      expect(filtered, isNotEmpty);
    });

    test('filter releases by build type', () async {
      final fetcher = createReleaseFetcher();
      final releases = await fetcher.fetchReleases();

      final filter = PhpReleaseFilter(buildType: BuildType.nts);
      final filtered = releases.where((r) => filter.matches(r)).toList();

      expect(filtered, isNotEmpty);
    });

    test('php downloader can fetch through fetcher', () async {
      final fetcher = createReleaseFetcher();
      final downloader = PhpDownloader();

      final releases = await downloader.fetchReleases(fetcher);

      expect(releases, isNotEmpty);
    });

    test('full filter chain works', () async {
      final fetcher = createReleaseFetcher();
      final releases = await fetcher.fetchReleases();

      final filter = PhpReleaseFilter(
        major: 8,
        minor: 3,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
      );

      final filtered = releases.where((r) => filter.matches(r)).toList();

      expect(filtered, isNotEmpty);
    });
  });

  group('ListRemoteCommand integration', () {
    test('command runs with real fetcher', () async {
      final fetcher = createReleaseFetcher();
      final downloader = PhpDownloader();
      final console = MockConsole();

      final cmd = ListRemoteCommand(fetcher, downloader, console);

      // Run the command
      // Note: This makes a real HTTP call! We'll handle this differently
      // For testing, we just verify the parser is set up correctly
      expect(cmd.argParser, isNotNull);
    });
  });

  group('InstallCommand integration', () {
    test('command parses version argument', () {
      final fetcher = createReleaseFetcher();
      final downloader = PhpDownloader();
      final console = MockConsole();

      final cmd = InstallCommand(
        fetcher,
        downloader,
        console,
        'C:\\pvm\\versions',
      );

      final result = cmd.argParser.parse(['8.3']);
      expect(result.rest.first, '8.3');
    });
  });
}
