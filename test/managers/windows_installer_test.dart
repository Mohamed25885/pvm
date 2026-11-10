import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/domain/php_release.dart';
import 'package:pvm/src/interfaces/i_installer.dart';
import 'package:pvm/src/managers/windows_installer.dart';
import 'package:pvm/src/services/release_fetcher.dart';

import '../mocks/mock_console.dart';

class _FakeFetcher implements IReleaseFetcher {
  final List<PhpRelease> releases;
  _FakeFetcher(this.releases);

  @override
  String get platformName => 'test';

  @override
  Future<List<PhpRelease>> fetchReleases() async => releases;
}

List<int> _zip(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach((name, data) => archive.addFile(ArchiveFile.bytes(name, data)));
  return ZipEncoder().encodeBytes(archive);
}

PhpRelease _release(List<int> zipBytes, {String? sha}) => PhpRelease(
  versionString: '8.3.1',
  major: 8,
  minor: 3,
  patch: 1,
  architecture: Architecture.x64,
  buildType: BuildType.nts,
  downloadUrl: 'https://windows.php.net/downloads/releases/php-8.3.1.zip',
  sha256: sha ?? crypto.sha256.convert(zipBytes).toString(),
  sizeBytes: zipBytes.length,
  lastModified: DateTime(2026),
);

void main() {
  late Directory temp;
  late String versions;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pvm_installer_');
    versions = p.join(temp.path, 'versions');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  WindowsInstaller installer(PhpRelease release, http.Client client) =>
      WindowsInstaller(
        versionsPath: versions,
        releaseFetcher: _FakeFetcher([release]),
        console: MockConsole(),
        client: client,
        retryDelay: Duration.zero,
      );

  MockClient serving(List<int> bytes) =>
      MockClient((_) async => http.Response.bytes(bytes, 200));

  test(
    'installs into the slot versions/<X.Y> and leaves no staging/temp leftovers',
    () async {
      final zip = _zip({
        'php.exe': [1],
        'ext/php_curl.dll': [2],
      });

      await installer(_release(zip), serving(zip)).install('8.3');

      expect(File(p.join(versions, '8.3', 'php.exe')).existsSync(), isTrue);
      expect(
        File(p.join(versions, '8.3', 'ext', 'php_curl.dll')).existsSync(),
        isTrue,
      );
      expect(Directory(versions).listSync().map((e) => p.basename(e.path)), [
        '8.3',
      ]);
    },
  );

  test('B1: SHA mismatch leaves no version directory behind', () async {
    final zip = _zip({
      'php.exe': [1],
    });

    await expectLater(
      installer(_release(zip, sha: 'deadbeef'), serving(zip)).install('8.3'),
      throwsA(isA<Exception>()),
    );

    expect(Directory(p.join(versions, '8.3')).existsSync(), isFalse);
    expect(Directory(versions).listSync(), isEmpty);
  });

  test('B1: download failure leaves no version directory behind', () async {
    final zip = _zip({
      'php.exe': [1],
    });
    final client = MockClient((_) async => http.Response('nope', 500));

    await expectLater(
      installer(_release(zip), client).install('8.3'),
      throwsA(isA<DownloadException>()),
    );
    expect(Directory(p.join(versions, '8.3')).existsSync(), isFalse);
  });

  test('empty checksum is rejected', () async {
    final zip = _zip({
      'php.exe': [1],
    });

    await expectLater(
      installer(_release(zip, sha: ''), serving(zip)).install('8.3'),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'S4: zip-slip into a sibling version directory aborts install',
    () async {
      final zip = _zip({
        'php.exe': [1],
        '../8.3.10/php.exe': [6, 6, 6],
      });

      await expectLater(
        installer(_release(zip), serving(zip)).install('8.3'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unsafe archive entry'),
          ),
        ),
      );
      expect(Directory(p.join(versions, '8.3')).existsSync(), isFalse);
      expect(Directory(p.join(versions, '8.3')).existsSync(), isFalse);
    },
  );

  test('archive without php.exe is rejected', () async {
    final zip = _zip({
      'readme.txt': [1],
    });

    await expectLater(
      installer(_release(zip), serving(zip)).install('8.3'),
      throwsA(isA<Exception>()),
    );
    expect(Directory(p.join(versions, '8.3')).existsSync(), isFalse);
  });

  test('B11: --force replaces the whole tree (no stale files)', () async {
    final stale = File(p.join(versions, '8.3', 'ext', 'old.dll'));
    await stale.create(recursive: true);
    await File(p.join(versions, '8.3', 'php.exe')).writeAsBytes([0]);
    final zip = _zip({
      'php.exe': [1],
    });

    await installer(
      _release(zip),
      serving(zip),
    ).install('8.3', options: InstallOptions(force: true));

    expect(stale.existsSync(), isFalse);
    expect(File(p.join(versions, '8.3', 'php.exe')).readAsBytesSync(), [1]);
  });

  test(
    'a leftover empty version dir is repaired, not "already installed"',
    () async {
      await Directory(p.join(versions, '8.3')).create(recursive: true);
      final zip = _zip({
        'php.exe': [1],
      });

      await installer(_release(zip), serving(zip)).install('8.3');

      expect(File(p.join(versions, '8.3', 'php.exe')).existsSync(), isTrue);
    },
  );

  test('B2: retries after a failed attempt and succeeds', () async {
    final zip = _zip({
      'php.exe': [1],
    });
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) throw http.ClientException('connection reset');
      return http.Response.bytes(zip, 200);
    });

    await installer(_release(zip), client).install('8.3');

    expect(calls, 2);
    expect(File(p.join(versions, '8.3', 'php.exe')).existsSync(), isTrue);
  });

  group('S7: download URL allow-list', () {
    Future<File> download(String url) {
      final zip = _zip({
        'php.exe': [1],
      });
      final release = PhpRelease(
        versionString: '8.3.1',
        major: 8,
        minor: 3,
        patch: 1,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: url,
        sha256: '',
        sizeBytes: 0,
        lastModified: DateTime(2026),
      );
      return installer(release, serving(zip)).downloadPhp(release, temp.path);
    }

    test('rejects look-alike hosts', () async {
      await expectLater(
        download('https://evilwindows.php.net/php.zip'),
        throwsA(isA<DownloadException>()),
      );
    });

    test('rejects plain http', () async {
      await expectLater(
        download('http://windows.php.net/php.zip'),
        throwsA(isA<DownloadException>()),
      );
    });

    test('accepts the official host', () async {
      final file = await download('https://windows.php.net/downloads/php.zip');
      expect(file.existsSync(), isTrue);
    });
  });
}
