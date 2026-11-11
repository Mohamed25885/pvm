import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/php_layout.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/domain/install_record.dart';
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

List<int> _tarGz(List<ArchiveFile> entries) {
  final archive = Archive();
  entries.forEach(archive.addFile);
  return GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
}

// Tests may check the host; lib/ may not (no_host_platform_checks_test).
final PlatformInfo _host = Platform.isWindows
    ? WindowsPlatformInfo()
    : LinuxPlatformInfo();

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

    ArtifactInstaller installer(
      PhpLayout layout,
      List<int> zip, {
      http.Client? client,
      List<String> hosts = const ['example.org'],
    }) => ArtifactInstaller(
      versionsPath: versions,
      layout: layout,
      platform: _host,
      allowedHosts: hosts,
      console: MockConsole(),
      client: client ?? MockClient((_) async => http.Response.bytes(zip, 200)),
      retryDelay: Duration.zero,
    );

    Future<void> installTarGz(
      List<int> tgz, {
      String version = '8.4.27',
      http.Client? client,
    }) => installer(PhpLayout.unix, tgz, client: client).install(
      _release(
        version,
        url: 'https://example.org/php-$version-cli-linux-x86_64.tar.gz',
        sha: crypto.sha256.convert(tgz).toString(),
      ),
      version,
      kind: SlotKind.static,
      allowUnverified: false,
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
        kind: SlotKind.windowsZip,
        allowUnverified: false,
      );

      expect(await unix.isInstalled('8.3.14'), isTrue);
      expect(Directory(p.join(versions, '8.3', 'conf.d')).existsSync(), isTrue);
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
          kind: SlotKind.windowsZip,
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
        installer(PhpLayout.windows, zip).install(
          _release('8.3.1'),
          '8.3.1',
          kind: SlotKind.windowsZip,
          allowUnverified: false,
        ),
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
          kind: SlotKind.windowsZip,
          allowUnverified: false,
        ),
        throwsA(isA<DownloadException>()),
      );
    });

    test('a slot that cannot be moved away is SlotInUseException', () async {
      final php = File(p.join(versions, '8.4', 'bin', 'php'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
      final tgz = _tarGz([
        ArchiveFile.bytes('php', [2]),
      ]);
      final locked = ArtifactInstaller(
        versionsPath: versions,
        layout: PhpLayout.unix,
        platform: _host,
        allowedHosts: const ['example.org'],
        console: MockConsole(),
        client: MockClient((_) async => http.Response.bytes(tgz, 200)),
        retryDelay: Duration.zero,
        renameDir: (dir, to) async =>
            p.equals(dir.path, p.dirname(php.parent.path))
            ? throw const FileSystemException('locked')
            : dir.rename(to),
      );

      await expectLater(
        locked.install(
          _release(
            '8.4.27',
            url: 'https://example.org/php-8.4.27-cli-linux-x86_64.tar.gz',
            sha: crypto.sha256.convert(tgz).toString(),
          ),
          '8.4.27',
          kind: SlotKind.static,
          allowUnverified: false,
        ),
        throwsA(
          isA<SlotInUseException>()
              .having((e) => e.slot, 'slot', '8.4')
              .having(
                (e) => '$e',
                'message',
                'PHP 8.4 is in use (a running php.exe or web server holds '
                    'its files). Stop it, then run: pvm update 8.4',
              ),
        ),
      );
      expect(php.readAsBytesSync(), [1]);
      expect(Directory(versions).listSync().map((e) => p.basename(e.path)), [
        '8.4',
      ]);
    });

    test('records the slot kind it was given', () async {
      await installTarGz(
        _tarGz([
          ArchiveFile.bytes('php', [1]),
        ]),
      );

      final record = await InstallRecord.readFrom(p.join(versions, '8.4'));
      expect(record!.kind, SlotKind.static);
      expect(record.version, '8.4.27');
    });

    test('a tar.gz with a lone php yields <slot>/bin/php, mode 0755', () async {
      await installTarGz(
        _tarGz([
          ArchiveFile.bytes('php', [7, 7]),
        ]),
      );

      final php = File(p.join(versions, '8.4', 'bin', 'php'));
      expect(php.readAsBytesSync(), [7, 7]);
      if (!Platform.isWindows) {
        expect(php.statSync().mode & 0x1ff, 0x1ed);
      }
    });

    test('a tar.gz with a tree is extracted as-is', () async {
      await installTarGz(
        _tarGz([
          ArchiveFile.bytes('bin/php', [1]),
          ArchiveFile.bytes('lib/x.ini', [2]),
        ]),
      );

      expect(File(p.join(versions, '8.4', 'lib', 'x.ini')).readAsBytesSync(), [
        2,
      ]);
    });

    for (final entry in [
      ArchiveFile.bytes('../evil', [1]),
      ArchiveFile.bytes('bin/../../evil', [1]),
      ArchiveFile.bytes('/abs/evil', [1]),
      ArchiveFile.symlink('bin/php', '/usr/bin/php'),
    ]) {
      test('rejects the tar entry ${entry.name} '
          '(symlink: ${entry.isSymbolicLink})', () async {
        await expectLater(
          installTarGz(
            _tarGz([
              ArchiveFile.bytes('lib/ok', [1]),
              entry,
            ]),
          ),
          throwsA(predicate((e) => '$e'.contains('Unsafe archive entry'))),
        );
        expect(Directory(versions).listSync(), isEmpty);
        expect(File(p.join(temp.path, 'evil')).existsSync(), isFalse);
      });
    }

    test('rejects a tar hard link entry', () async {
      final link = ArchiveFile.symlink('bin/php', 'lib/ok')..isHardLink = true;
      await expectLater(
        installTarGz(
          _tarGz([
            ArchiveFile.bytes('lib/ok', [1]),
            link,
          ]),
        ),
        throwsA(predicate((e) => '$e'.contains('Unsafe archive entry'))),
      );
      expect(Directory(versions).listSync(), isEmpty);
    });

    test('rejects an archive URL that is neither zip nor tar.gz', () async {
      final tgz = _tarGz([
        ArchiveFile.bytes('php', [1]),
      ]);
      await expectLater(
        installer(PhpLayout.unix, tgz).install(
          _release(
            '8.4.27',
            url: 'https://example.org/php.tar.xz',
            sha: crypto.sha256.convert(tgz).toString(),
          ),
          '8.4.27',
          kind: SlotKind.static,
          allowUnverified: false,
        ),
        throwsA(predicate((e) => '$e'.contains('Unsupported archive'))),
      );
      expect(Directory(versions).existsSync(), isFalse);
    });

    test('a stream that fails halfway leaves the old slot intact', () async {
      final old = Directory(p.join(versions, '8.4', 'bin'))
        ..createSync(recursive: true);
      File(p.join(old.path, 'php')).writeAsBytesSync([1, 2, 3]);
      File(p.join(versions, '8.4', 'keep.txt')).writeAsStringSync('old');
      final before = await InstallRecord.hashTree(p.join(versions, '8.4'));

      final tgz = _tarGz([ArchiveFile.bytes('php', List.filled(4096, 9))]);
      final dropping = MockClient.streaming((_, _) async {
        Stream<List<int>> body() async* {
          yield tgz.sublist(0, tgz.length ~/ 2);
          throw const SocketException('connection reset');
        }

        return http.StreamedResponse(body(), 200, contentLength: tgz.length);
      });

      await expectLater(
        installTarGz(tgz, client: dropping),
        throwsA(isA<SocketException>()),
      );

      expect(await InstallRecord.hashTree(p.join(versions, '8.4')), before);
      expect(Directory(versions).listSync().map((e) => p.basename(e.path)), [
        '8.4',
      ]);
    });

    test('removes stale .staging-<slot>-* dirs before installing', () async {
      final stale = Directory(p.join(versions, '.staging-8.4-99999'))
        ..createSync(recursive: true);
      File(p.join(stale.path, 'junk')).writeAsStringSync('x');
      final other = Directory(p.join(versions, '.staging-8.3-99999'))
        ..createSync(recursive: true);

      await installTarGz(
        _tarGz([
          ArchiveFile.bytes('php', [1]),
        ]),
      );

      expect(stale.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
    });

    group('redirects (R11)', () {
      final tgz = _tarGz([
        ArchiveFile.bytes('php', [1]),
      ]);
      late List<http.Request> seen;

      const start = 'https://example.org/php-8.4.27-cli-linux-x86_64.tar.gz';

      // Each hop's Location comes from the previous URL (keyed by URL, so the
      // download's retries replay the same chain); the last URL serves tgz.
      http.Client redirecting(List<String> hops) {
        seen = [];
        final next = <String, String>{};
        var from = Uri.parse(start);
        for (final hop in hops) {
          next['$from'] = hop;
          from = from.resolve(hop);
        }
        return MockClient((req) async {
          seen.add(req);
          final location = next['${req.url}'];
          if (location != null) {
            return http.Response('', 302, headers: {'location': location});
          }
          return http.Response.bytes(tgz, 200);
        });
      }

      test('follows an https chain (relative, then absolute), UA on every '
          'hop', () async {
        await installTarGz(
          tgz,
          client: redirecting(['/down?path=x', 'https://cdn.example.net/php']),
        );

        expect(seen.map((r) => r.url.toString()), [
          'https://example.org/php-8.4.27-cli-linux-x86_64.tar.gz',
          'https://example.org/down?path=x',
          'https://cdn.example.net/php',
        ]);
        for (final r in seen) {
          expect(r.followRedirects, isFalse);
          expect(r.headers['User-Agent'], PvmConstants.userAgent);
        }
        expect(
          File(p.join(versions, '8.4', 'bin', 'php')).existsSync(),
          isTrue,
        );
      });

      test('a hop to http:// is refused and nothing is installed', () async {
        await expectLater(
          installTarGz(
            tgz,
            client: redirecting(['/down', 'http://cdn.example.net/php']),
          ),
          throwsA(
            isA<DownloadException>().having(
              (e) => e.message,
              'message',
              contains('non-https'),
            ),
          ),
        );
        expect(seen.map((r) => r.url.scheme), everyElement('https'));
        expect(Directory(versions).listSync(), isEmpty);
      });

      test('more than 5 redirects are refused', () async {
        await expectLater(
          installTarGz(
            tgz,
            client: redirecting(List.generate(6, (i) => '/hop$i')),
          ),
          throwsA(
            isA<DownloadException>().having(
              (e) => e.message,
              'message',
              contains('Too many redirects'),
            ),
          ),
        );
        expect(Directory(versions).listSync(), isEmpty);
      });
    });

    test('accepts dl.static-php.dev when it is an allowed host', () async {
      final tgz = _tarGz([
        ArchiveFile.bytes('php', [1]),
      ]);
      final static = installer(
        PhpLayout.unix,
        tgz,
        hosts: const ['dl.static-php.dev'],
      );

      await static.install(
        _release(
          '8.4.27',
          url:
              'https://dl.static-php.dev/v3/php-bin/bulk/'
              'php-8.4.27-cli-linux-x86_64.tar.gz',
          sha: crypto.sha256.convert(tgz).toString(),
        ),
        '8.4.27',
        kind: SlotKind.static,
        allowUnverified: false,
      );

      expect(await static.isInstalled('8.4.27'), isTrue);
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
