import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/domain/php_release.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/interfaces/i_installer.dart';
import 'package:pvm/src/interfaces/i_release_source.dart';
import 'package:pvm/src/managers/static_php_installer.dart';
import 'package:pvm/src/services/folder_probe.dart';
import 'package:test/test.dart';

import '../mocks/mock_console.dart';
import '../services/fake_process_manager.dart';

// Tests may check the host; lib/ may not (no_host_platform_checks_test).
final PlatformInfo _host = Platform.isWindows
    ? WindowsPlatformInfo()
    : LinuxPlatformInfo();

final _tgz = GZipEncoder().encodeBytes(
  TarEncoder().encodeBytes(Archive()..addFile(ArchiveFile.bytes('php', [7]))),
);

/// Serves the newest patch of each slot from [patches].
class _Source implements IReleaseSource {
  final Map<String, int> patches;
  final requested = <PhpVersion>[];
  _Source(this.patches);

  @override
  String get name => 'test';

  @override
  Future<PhpRelease> resolve(
    PhpVersion version, {
    required Architecture architecture,
    required BuildType buildType,
  }) async {
    requested.add(version);
    final patch = version.patch ?? patches[version.slot]!;
    final v = '${version.slot}.$patch';
    return PhpRelease(
      versionString: v,
      major: version.major,
      minor: version.minor,
      patch: patch,
      architecture: architecture,
      buildType: BuildType.nts,
      downloadUrl:
          'https://dl.static-php.dev/v3/php-bin/bulk/'
          'php-$v-cli-linux-x86_64.tar.gz',
      sha256: crypto.sha256.convert(_tgz).toString(),
      sizeBytes: 0,
      lastModified: DateTime(2026),
    );
  }
}

void main() {
  late Directory temp;
  late String versions;
  late FakeProcessManager pm;
  late MockConsole console;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pvm_static_');
    versions = p.join(temp.path, 'versions');
    pm = FakeProcessManager();
    console = MockConsole();
  });

  tearDown(() async => temp.delete(recursive: true));

  String staging(String slot) => p.join(versions, '.staging-$slot-$pid');

  void probeReports(String slot, {String? ext, int exitCode = 0}) {
    final stage = staging(slot);
    pm.capturedResults[p.join(stage, 'bin', 'php')] = CapturedProcessResult(
      exitCode: exitCode,
      stdout: jsonEncode({
        'v': '$slot.27',
        'zts': false,
        'arch': 'aarch64',
        'ext': ext ?? p.join(stage, 'lib', 'php', 'extensions'),
        'build': 'API20240924,NTS',
      }),
      stderr: exitCode == 0 ? '' : 'boom',
    );
  }

  StaticPhpInstaller installer(_Source source) => StaticPhpInstaller(
    versionsPath: versions,
    source: source,
    platform: _host,
    console: console,
    probe: FolderProbe(pm, LinuxPlatformInfo()),
    client: MockClient((_) async => http.Response.bytes(_tgz, 200)),
    retryDelay: Duration.zero,
  );

  Future<void> seedSlot(String slot, String version) async {
    final php = File(p.join(versions, slot, 'bin', 'php'));
    await php.create(recursive: true);
    await php.writeAsBytes([1]);
    await InstallRecord(
      version: version,
      sourceUrl: '',
      archiveSha256: '',
      verified: true,
      installedAt: DateTime(2026),
      files: const {},
      kind: SlotKind.static,
    ).writeTo(p.join(versions, slot));
  }

  test('install 8.4 writes versions/8.4/bin/php with a static record whose '
      'fields come from the probe run inside staging', () async {
    probeReports('8.4');

    final result = await installer(_Source({'8.4': 27})).install('8.4');

    expect(result.version, '8.4.27');
    expect(File(p.join(versions, '8.4', 'bin', 'php')).readAsBytesSync(), [7]);
    final record = (await InstallRecord.readFrom(p.join(versions, '8.4')))!;
    expect(record.kind, SlotKind.static);
    expect(record.version, '8.4.27');
    expect(record.phpConfig, isNull);
    expect(record.arch, 'arm64');
    expect(record.apiNo, '20240924');
    expect(record.zts, isFalse);
    // A path inside staging is rewritten to the committed slot.
    expect(
      record.extensionDir,
      p.join(versions, '8.4', 'lib', 'php', 'extensions'),
    );
    expect(pm.capturedSpecs.single.executable, startsWith(staging('8.4')));
    expect(Directory(staging('8.4')).existsSync(), isFalse);
  });

  test(
    'a failing probe aborts a static install and keeps the old slot',
    () async {
      await seedSlot('8.4', '8.4.27');
      final before = await InstallRecord.hashTree(p.join(versions, '8.4'));
      probeReports('8.4', exitCode: 1);

      await expectLater(
        installer(
          _Source({'8.4': 27}),
        ).install('8.4', options: const InstallOptions(force: true)),
        throwsA(isA<Exception>()),
      );

      expect(await InstallRecord.hashTree(p.join(versions, '8.4')), before);
      expect(Directory(staging('8.4')).existsSync(), isFalse);
    },
  );

  test('a different patch in a filled slot is SlotFilledException', () async {
    await seedSlot('8.2', '8.2.28');

    await expectLater(
      installer(_Source({'8.2': 29})).install('8.2.29'),
      throwsA(
        isA<SlotFilledException>()
            .having((e) => e.slot, 'slot', '8.2')
            .having((e) => e.installed, 'installed', '8.2.28')
            .having(
              (e) => e.toString(),
              'message',
              '8.2 is installed (8.2.28). Run: pvm update 8.2',
            ),
      ),
    );
  });

  test('--force does not replace a different patch', () async {
    await seedSlot('8.2', '8.2.28');

    await expectLater(
      installer(
        _Source({'8.2': 29}),
      ).install('8.2.29', options: const InstallOptions(force: true)),
      throwsA(isA<SlotFilledException>()),
    );
  });

  test('install 8.2 resolves the newest patch before the slot check', () async {
    await seedSlot('8.2', '8.2.28');
    final source = _Source({'8.2': 29});

    await expectLater(
      installer(source).install('8.2'),
      throwsA(isA<SlotFilledException>()),
    );
    expect(source.requested.single.toString(), '8.2');
  });

  test('the same patch is already installed; --force reinstalls it', () async {
    await seedSlot('8.4', '8.4.27');

    final again = await installer(_Source({'8.4': 27})).install('8.4');
    expect(again.alreadyInstalled, isTrue);

    probeReports('8.4');
    final forced = await installer(
      _Source({'8.4': 27}),
    ).install('8.4', options: const InstallOptions(force: true));
    expect(forced.alreadyInstalled, isFalse);
    expect(File(p.join(versions, '8.4', 'bin', 'php')).readAsBytesSync(), [7]);
  });
}
