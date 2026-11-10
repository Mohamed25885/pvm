import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pvm/src/core/php_layout.dart';
import 'package:pvm/src/domain/php_release.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/interfaces/i_installer.dart';
import 'package:pvm/src/services/installation/artifact_installer.dart';
import 'package:pvm/src/services/release_fetcher.dart';
import 'package:pvm/src/services/windows_release_source.dart';
import 'package:test/test.dart';

import '../../mocks/mock_console.dart';

List<int> _zip(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach((name, data) => archive.addFile(ArchiveFile.bytes(name, data)));
  return ZipEncoder().encodeBytes(archive);
}

PhpRelease _release(
  String version, {
  String url = 'https://example.org/php.zip',
  String sha = '',
}) {
  final v = PhpVersion.parse(version);
  return PhpRelease(
    versionString: version,
    major: v.major,
    minor: v.minor,
    patch: v.patch,
    architecture: Architecture.x64,
    buildType: BuildType.nts,
    downloadUrl: url,
    sha256: sha,
    sizeBytes: 0,
    lastModified: DateTime(2026),
  );
}

class _Fetcher implements IReleaseFetcher {
  final List<PhpRelease> releases;
  _Fetcher(this.releases);

  @override
  String get platformName => 'test';

  @override
  Future<List<PhpRelease>> fetchReleases() async => releases;
}

void main() {
  group('ArtifactInstaller (2.6)', () {
    late Directory temp;
    late String versions;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('pvm_artifact_');
      versions = p.join(temp.path, 'versions');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    ArtifactInstaller installer(PhpLayout layout, List<int> zip) =>
        ArtifactInstaller(
          versionsPath: versions,
          layout: layout,
          allowedHosts: const ['example.org'],
          console: MockConsole(),
          client: MockClient((_) async => http.Response.bytes(zip, 200)),
          retryDelay: Duration.zero,
        );

    test('installs a Unix-layout build (bin/php) atomically', () async {
      final zip = _zip({
        'bin/php': [1],
        'lib/php.ini-development': [2],
      });
      final sha = crypto.sha256.convert(zip).toString();
      final unix = installer(PhpLayout.unix, zip);

      await unix.install(
        _release('8.3.14', sha: sha),
        '8.3.14',
        allowUnverified: false,
      );

      expect(await unix.isInstalled('8.3.14'), isTrue);
      expect(
        File(p.join(versions, '8.3', '.pvm-install.json')).existsSync(),
        isTrue,
      );
      expect(Directory(versions).listSync().map((e) => p.basename(e.path)), [
        '8.3',
      ]);
    });

    test('rejects an archive without the layout binary', () async {
      final zip = _zip({
        'php.exe': [1],
      });
      final sha = crypto.sha256.convert(zip).toString();

      await expectLater(
        installer(PhpLayout.unix, zip).install(
          _release('8.3.14', sha: sha),
          '8.3.14',
          allowUnverified: false,
        ),
        throwsA(predicate((e) => '$e'.contains(p.join('bin', 'php')))),
      );
      expect(Directory(versions).listSync(), isEmpty);
    });

    test('refuses an unverified build unless allowed', () async {
      final zip = _zip({
        'php.exe': [1],
      });

      await expectLater(
        installer(
          PhpLayout.windows,
          zip,
        ).install(_release('8.3.1'), '8.3.1', allowUnverified: false),
        throwsA(isA<UnverifiedReleaseException>()),
      );
      expect(Directory(versions).existsSync(), isFalse);
    });

    test('only downloads over https from allowed hosts', () async {
      final zip = _zip({
        'php.exe': [1],
      });
      final sha = crypto.sha256.convert(zip).toString();

      await expectLater(
        installer(PhpLayout.windows, zip).install(
          _release(
            '8.3.1',
            url: 'https://example.org.evil.com/x.zip',
            sha: sha,
          ),
          '8.3.1',
          allowUnverified: false,
        ),
        throwsA(isA<DownloadException>()),
      );
    });
  });

  group('WindowsReleaseSource (2.6)', () {
    test('picks the newest matching patch', () async {
      final source = WindowsReleaseSource(
        fetcher: _Fetcher([
          _release('8.3.12'),
          _release('8.3.14'),
          _release('8.2.30'),
        ]),
      );

      final release = await source.resolve(
        PhpVersion.parse('8.3'),
        architecture: Architecture.x64,
        buildType: BuildType.nts,
      );

      expect(release.displayVersion, '8.3.14');
    });

    test('no match is NoMatchingReleaseException, not a network error', () {
      final source = WindowsReleaseSource(fetcher: _Fetcher([]));

      expect(
        source.resolve(
          PhpVersion.parse('7.0'),
          architecture: Architecture.x64,
          buildType: BuildType.nts,
        ),
        throwsA(isA<NoMatchingReleaseException>()),
      );
    });
  });
}
