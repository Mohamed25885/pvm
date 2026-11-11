import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvm/src/domain/php_release.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/interfaces/i_installer.dart';
import 'package:pvm/src/services/release_fetcher.dart';
import 'package:pvm/src/services/static_php_release_source.dart';
import 'package:pvm/src/version.dart';
import 'package:test/test.dart';

const _bulk = 'https://dl.static-php.dev/v3/php-bin/bulk/';
const _sha = 'd856b480ec37608f5f8231080ecae9fd0e1c6b6dedea77459cd420674f45b234';

void main() {
  final listing = File(
    'test/fixtures/static_php_bulk_listing.html',
  ).readAsStringSync();

  late List<http.Request> requests;

  StaticPhpReleaseSource source({String os = 'linux', String? html}) {
    requests = [];
    return StaticPhpReleaseSource(
      os: os,
      client: MockClient((req) async {
        requests.add(req);
        final url = req.url.toString();
        if (url == _bulk) {
          // The real page is UTF-8 (it contains a bullet character).
          return http.Response(
            html ?? listing,
            200,
            headers: {'content-type': 'text/html; charset=UTF-8'},
          );
        }
        if (url.endsWith('.sha256')) {
          final file = Uri.parse(url).pathSegments.last;
          return http.Response(
            '$_sha  ${file.replaceAll('.sha256', '')}\n',
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );
  }

  Future<PhpRelease> resolve(
    StaticPhpReleaseSource s,
    String version, {
    Architecture arch = Architecture.x64,
  }) => s.resolve(
    PhpVersion.parse(version),
    architecture: arch,
    buildType: BuildType.nts,
  );

  group('StaticPhpReleaseSource', () {
    test('8.4 picks the newest cli build with a .sha256 sidecar', () async {
      final release = await resolve(source(), '8.4');

      expect(release.displayVersion, '8.4.27');
      expect(release.downloadUrl, '${_bulk}php-8.4.27-cli-linux-x86_64.tar.gz');
      expect(release.architecture, Architecture.x64);
      expect(release.buildType, BuildType.nts);
    });

    test('arm64 on macOS maps to aarch64 builds', () async {
      final release = await resolve(
        source(os: 'macos'),
        '8.4',
        arch: Architecture.arm64,
      );

      expect(
        release.downloadUrl,
        '${_bulk}php-8.4.27-cli-macos-aarch64.tar.gz',
      );
    });

    test('an exact patch returns exactly that build', () async {
      final release = await resolve(source(), '8.4.27');

      expect(release.displayVersion, '8.4.27');
      expect(release.patch, 27);
    });

    test('a build without a .sha256 sidecar is not eligible', () {
      // 8.4.24 is listed for linux-x86_64, but without a checksum.
      expect(
        resolve(source(), '8.4.24'),
        throwsA(isA<NoMatchingReleaseException>()),
      );
    });

    test('a missing patch lists the available 8.3.x (Q7)', () async {
      await expectLater(
        resolve(source(), '8.3.34'),
        throwsA(
          isA<NoMatchingReleaseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('8.3.34'), contains('8.3.36')),
          ),
        ),
      );
    });

    test('x86 has no static builds', () {
      expect(
        resolve(source(), '8.4', arch: Architecture.x86),
        throwsA(isA<NoMatchingReleaseException>()),
      );
    });

    test('every request carries the PVM User-Agent', () async {
      await resolve(source(), '8.4');

      expect(requests, hasLength(2));
      for (final r in requests) {
        expect(
          r.headers['User-Agent'],
          'pvm/$packageVersion (+https://github.com/Mohamed25885/pvm)',
        );
      }
    });

    test('sha256 is the first token of the sidecar body', () async {
      final release = await resolve(source(), '8.4');

      expect(release.sha256, _sha);
      expect(
        requests.last.url.toString(),
        '${_bulk}php-8.4.27-cli-linux-x86_64.tar.gz.sha256',
      );
    });

    test('patches compare numerically (8.4.10 > 8.4.9)', () async {
      const html =
          '<a href="/v3/php-bin/bulk/php-8.4.9-cli-linux-x86_64.tar.gz">a</a>'
          '<a href="/v3/php-bin/bulk/php-8.4.9-cli-linux-x86_64.tar.gz.sha256">b</a>'
          '<a href="/v3/php-bin/bulk/php-8.4.10-cli-linux-x86_64.tar.gz">c</a>'
          '<a href="/v3/php-bin/bulk/php-8.4.10-cli-linux-x86_64.tar.gz.sha256">d</a>';

      final release = await resolve(source(html: html), '8.4');

      expect(release.displayVersion, '8.4.10');
    });

    test('an unreachable listing is a ReleaseFetcherException', () {
      final s = StaticPhpReleaseSource(
        os: 'linux',
        client: MockClient((_) async => http.Response('down', 503)),
      );

      expect(resolve(s, '8.4'), throwsA(isA<ReleaseFetcherException>()));
    });
  });
}
