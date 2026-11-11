import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/domain/php_release.dart';
import 'package:pvm/src/interfaces/i_installer.dart';
import 'package:pvm/src/managers/windows_installer.dart';
import 'package:pvm/src/services/release_fetcher.dart';
import 'package:pvm/src/services/windows_archive_index.dart';

import '../mocks/mock_console.dart';
import '../support/temp_dir.dart';

class _FakeFetcher implements IReleaseFetcher {
  final List<PhpRelease> releases;
  final Object? error;
  _FakeFetcher(this.releases, {this.error});

  @override
  String get platformName => 'test';

  @override
  Future<List<PhpRelease>> fetchReleases() async {
    if (error != null) throw error!;
    return releases;
  }
}

List<int> _zip(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach((name, data) => archive.addFile(ArchiveFile.bytes(name, data)));
  return ZipEncoder().encodeBytes(archive);
}

PhpRelease _current(List<int> zip, {int patch = 14}) => PhpRelease(
  versionString: '8.3.$patch',
  major: 8,
  minor: 3,
  patch: patch,
  architecture: Architecture.x64,
  buildType: BuildType.nts,
  downloadUrl: 'https://windows.php.net/downloads/releases/php-8.3.$patch.zip',
  sha256: crypto.sha256.convert(zip).toString(),
  sizeBytes: zip.length,
  lastModified: DateTime(2026),
);

const _listing = '''
<a href="php-8.3.2-Win32-vs16-x64.zip">x</a>
<a href="php-8.3.2-nts-Win32-vs16-x64.zip">x</a>
<a href="php-8.3.2-nts-Win32-vs16-x86.zip">x</a>
<a href="php-debug-pack-8.3.2-nts-Win32-vs16-x64.zip">x</a>
<a href="php-8.3.2-src.zip">x</a>
''';

void main() {
  late Directory temp;
  late String versions;
  late List<int> zip;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pvm_archive_');
    versions = p.join(temp.path, 'versions');
    zip = _zip({
      'php.exe': [1],
      'ext/php_curl.dll': [2],
    });
  });

  tearDown(() async => deleteTemp(temp));

  WindowsInstaller installer({List<PhpRelease>? releases, Object? fetchError}) {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/archives/')) {
        return http.Response(_listing, 200);
      }
      return http.Response.bytes(zip, 200);
    });
    return WindowsInstaller(
      versionsPath: versions,
      releaseFetcher: _FakeFetcher(
        releases ?? [_current(zip)],
        error: fetchError,
      ),
      console: MockConsole(),
      client: client,
      retryDelay: Duration.zero,
      archiveIndex: WindowsArchiveIndex(client: client),
    );
  }

  group('WindowsArchiveIndex.parse', () {
    test('keeps only php builds and reads arch / build type', () {
      final releases = WindowsArchiveIndex.parse(_listing);

      expect(releases, hasLength(3));
      expect(releases.every((r) => r.displayVersion == '8.3.2'), isTrue);
      expect(releases.every((r) => r.sha256.isEmpty), isTrue);
      expect(
        releases.map((r) => '${r.buildType.name}-${r.architecture.name}'),
        containsAll(['ts-x64', 'nts-x64', 'nts-x86']),
      );
      expect(
        releases.first.downloadUrl,
        startsWith('https://downloads.php.net/~windows/releases/archives/'),
      );
    });
  });

  group('B7: older patches from the archive', () {
    test('refuses an unverified archive build without opt-in', () async {
      await expectLater(
        installer().install('8.3.2'),
        throwsA(isA<UnverifiedReleaseException>()),
      );
      expect(Directory(p.join(versions, '8.3')).existsSync(), isFalse);
    });

    test('installs it with --allow-unverified and records it', () async {
      final result = await installer().install(
        '8.3.2',
        options: const InstallOptions(allowUnverified: true),
      );

      expect(result.version, '8.3.2');
      final dir = p.join(versions, '8.3');
      expect(File(p.join(dir, 'php.exe')).existsSync(), isTrue);
      final record = await InstallRecord.readFrom(dir);
      expect(record, isNotNull);
      expect(record!.verified, isFalse);
      expect(record.archiveSha256, crypto.sha256.convert(zip).toString());
    });

    test('patch not in archive either → NoMatchingReleaseException', () async {
      await expectLater(
        installer().install('8.3.99'),
        throwsA(isA<NoMatchingReleaseException>()),
      );
    });

    test('major.minor never consults the archive', () async {
      final result = await installer().install('8.3');
      expect(result.version, '8.3.14');
    });
  });

  test('B6: fetcher errors propagate instead of "no match"', () async {
    await expectLater(
      installer(
        fetchError: const ReleaseFetcherException('offline'),
      ).install('8.3'),
      throwsA(isA<ReleaseFetcherException>()),
    );
  });

  test(
    'already installed returns alreadyInstalled without downloading',
    () async {
      await File(p.join(versions, '8.3', 'php.exe')).create(recursive: true);

      final result = await installer().install('8.3');

      expect(result.alreadyInstalled, isTrue);
      expect(result.version, '8.3.14');
    },
  );

  group('S8: install record', () {
    test('verified install records hashes of every file', () async {
      await installer().install('8.3');
      final dir = p.join(versions, '8.3');

      final record = (await InstallRecord.readFrom(dir))!;

      expect(record.verified, isTrue);
      expect(record.files.keys, containsAll(['php.exe', 'ext/php_curl.dll']));
      expect((await record.verify(dir)).isIntact, isTrue);
    });

    test(
      'verify detects modified and missing files; added are informational',
      () async {
        await installer().install('8.3');
        final dir = p.join(versions, '8.3');
        await File(p.join(dir, 'php.exe')).writeAsBytes([6, 6, 6]);
        await File(p.join(dir, 'ext', 'php_curl.dll')).delete();
        await File(p.join(dir, 'php.ini')).writeAsString('memory_limit=1G');

        final result = await (await InstallRecord.readFrom(dir))!.verify(dir);

        expect(result.isIntact, isFalse);
        expect(result.modified, ['php.exe']);
        expect(result.missing, ['ext/php_curl.dll']);
        expect(result.added, ['php.ini']);
      },
    );
  });
}
