import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/version_registry.dart';
import 'package:pvm/src/services/extensions/pecl_windows_dll.dart';
import 'package:test/test.dart';

import '../../mocks/mock_console.dart';

List<int> _zip(Map<String, List<int>> files) {
  final a = Archive();
  files.forEach((n, b) => a.addFile(ArchiveFile(n, b.length, b)));
  return ZipEncoder().encode(a);
}

class _Pm implements IProcessManager {
  final captured = <ProcessSpec>[];

  @override
  Future<int> runInteractive(ProcessSpec spec) async => 0;

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    captured.add(spec);
    return CapturedProcessResult(
      stdout: '[Zend Modules]\nXdebug\n',
      stderr: '',
      exitCode: 0,
    );
  }

  @override
  Future<String> resolveSystemCommand(String command) async => command;
}

void main() {
  late Directory temp;
  late String slotDir;
  late _Pm pm;
  late List<Uri> requested;
  late int zipStatus;
  late List<int> zip;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pvm_dll_');
    slotDir = p.join(temp.path, 'versions', '8.4');
    File(p.join(slotDir, 'php.exe')).createSync(recursive: true);
    File(p.join(slotDir, 'same.dll')).writeAsBytesSync([5]);
    pm = _Pm();
    requested = [];
    zipStatus = 200;
    zip = _zip({
      'php_xdebug.dll': [1, 2, 3],
      'libdep.dll': [7],
      'same.dll': [5],
      'README.md': [0],
    });
  });
  tearDown(() async => temp.delete(recursive: true));

  InstalledSlot slot({
    bool zts = false,
    String arch = 'x64',
    String? vs = 'VS17',
  }) => InstalledSlot(
    PhpVersion.parse('8.4.27'),
    slotDir,
    InstallRecord(
      version: '8.4.27',
      sourceUrl: '',
      archiveSha256: '',
      verified: true,
      installedAt: DateTime.utc(2026),
      files: const {},
      kind: SlotKind.windowsZip,
      zts: zts,
      arch: arch,
      vsVersion: vs,
      extensionDir: p.join(slotDir, 'ext'),
    ),
  );

  PeclWindowsDll route() => PeclWindowsDll(
    platform: WindowsPlatformInfo(),
    console: MockConsole(),
    processManager: pm,
    client: MockClient((r) async {
      requested.add(r.url);
      if (r.url.path.endsWith('stable.txt')) {
        return http.Response('3.5.3\n', 200);
      }
      return zipStatus == 200
          ? http.Response.bytes(zip, 200)
          : http.Response('', zipStatus);
    }),
    retryDelay: Duration.zero,
  );

  test('downloads the record-matched zip, installs the dll and its deps, '
      'returns an unverified entry with the zip hash', () async {
    final entry = await route().install('xdebug', slot());

    expect(requested.map((u) => u.toString()), [
      'https://pecl.php.net/rest/r/xdebug/stable.txt',
      'https://downloads.php.net/~windows/pecl/releases/xdebug/3.5.3/'
          'php_xdebug-3.5.3-8.4-nts-vs17-x64.zip',
    ]);
    expect(File(p.join(slotDir, 'ext', 'php_xdebug.dll')).readAsBytesSync(), [
      1,
      2,
      3,
    ]);
    expect(File(p.join(slotDir, 'libdep.dll')).readAsBytesSync(), [7]);
    expect(File(p.join(slotDir, 'README.md')).existsSync(), isFalse);
    expect(File(p.join(slotDir, 'php_xdebug.dll')).existsSync(), isFalse);
    expect(pm.captured.single.executable, p.join(slotDir, 'php.exe'));

    expect(entry.name, 'xdebug');
    expect(entry.version, '3.5.3');
    expect(entry.file, 'php_xdebug.dll');
    expect(entry.sha256, crypto.sha256.convert(zip).toString());
    expect(entry.verified, isFalse);
  });

  test('builds the URL from zts, vsVersion and arch', () async {
    await route().install('xdebug', slot(zts: true, arch: 'x86', vs: 'VS16'));
    expect(
      requested.last.path,
      '/~windows/pecl/releases/xdebug/3.5.3/'
      'php_xdebug-3.5.3-8.4-ts-vs16-x86.zip',
    );
  });

  test('a 404 on the zip is ExtensionUnavailableException', () async {
    zipStatus = 404;
    await expectLater(
      route().install('xdebug', slot()),
      throwsA(
        isA<ExtensionUnavailableException>().having(
          (e) => e.message,
          'message',
          'xdebug 3.5.3 has no Windows build for PHP 8.4 NTS VS17 x64',
        ),
      ),
    );
    expect(Directory(p.join(slotDir, 'ext')).existsSync(), isFalse);
  });

  test('no recorded vsVersion refuses before any download', () async {
    await expectLater(
      route().install('xdebug', slot(vs: null)),
      throwsA(
        isA<ExtensionUnavailableException>().having(
          (e) => e.message,
          'message',
          'PHP 8.4 has no recorded VS version; run: pvm update 8.4',
        ),
      ),
    );
    expect(requested, isEmpty);
  });

  test('arm64 is unavailable', () async {
    await expectLater(
      route().install('xdebug', slot(arch: 'arm64')),
      throwsA(isA<ExtensionUnavailableException>()),
    );
    expect(requested, isEmpty);
  });
}
