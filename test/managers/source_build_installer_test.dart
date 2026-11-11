import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/interfaces/i_installer.dart';
import 'package:pvm/src/managers/source_build_installer.dart';
import 'package:pvm/src/services/build_tools.dart';
import 'package:pvm/src/services/folder_probe.dart';
import 'package:test/test.dart';

import '../mocks/mock_console.dart';

final _tarball = utf8.encode('fake php source tarball');
final _sha = crypto.sha256.convert(_tarball).toString();

/// Plays the build tools: `make install INSTALL_ROOT=<root>` writes
/// `<root><prefix>/bin/{php,php-config}`; the staged php answers the probe.
class _Pm implements IProcessManager {
  final String prefix;
  final interactive = <ProcessSpec>[];
  final captured = <ProcessSpec>[];
  String? failOn; // first argument of a `make` step that fails
  _Pm(this.prefix);

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    interactive.add(spec);
    final args = spec.arguments;
    if (spec.executable == 'make' && args.isNotEmpty && args.first == failOn) {
      return 2;
    }
    if (spec.executable == 'make' && args.first == 'install') {
      final root = args[1].substring('INSTALL_ROOT='.length);
      final bin = p.join(
        root,
        p.relative(prefix, from: p.rootPrefix(prefix)),
        'bin',
      );
      for (final name in ['php', 'php-config']) {
        File(p.join(bin, name))
          ..createSync(recursive: true)
          ..writeAsStringSync(name);
      }
    }
    return 0;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    captured.add(spec);
    var out = '';
    if (spec.executable == 'brew') {
      final ok = spec.arguments.last == 'openssl@3';
      return CapturedProcessResult(
        stdout: ok ? '/opt/homebrew/opt/openssl@3' : '',
        stderr: '',
        exitCode: ok ? 0 : 1,
      );
    }
    if (spec.executable.endsWith('php')) {
      out = jsonEncode({
        'v': '8.4.27',
        'zts': false,
        'arch': 'x86_64',
        'ext': p.join(prefix, 'lib', 'php', 'extensions'),
        'build': 'API20240924,NTS',
      });
    } else if (spec.executable.endsWith('php-config')) {
      out = '$prefix\n';
    }
    return CapturedProcessResult(stdout: out, stderr: '', exitCode: 0);
  }

  @override
  Future<String> resolveSystemCommand(String command) async => command;
}

void main() {
  late Directory temp;
  late String versions;
  late String prefix;
  late _Pm pm;
  late MockConsole console;
  late List<Uri> requested;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pvm_src_');
    versions = p.join(temp.path, 'versions');
    prefix = p.join(versions, '8.4');
    pm = _Pm(prefix);
    console = MockConsole();
    requested = [];
  });

  tearDown(() async => temp.delete(recursive: true));

  String staging() => p.join(versions, '.staging-8.4-$pid');

  SourceBuildInstaller installer({
    String? sha = 'ok',
    String patch = '27',
    PlatformInfo? platform,
  }) {
    final os = platform ?? LinuxPlatformInfo();
    final v = '8.4.$patch';
    final json = jsonEncode({
      'version': v,
      'source': [
        {'filename': 'php-$v.tar.gz', 'sha256': 'f' * 64},
        {
          'filename': 'php-$v.tar.xz',
          if (sha != null) 'sha256': sha == 'ok' ? _sha : sha,
        },
      ],
    });
    return SourceBuildInstaller(
      versionsPath: versions,
      platform: os,
      console: console,
      processManager: pm,
      buildTools: BuildTools(
        pm,
        os,
        osReleasePath: p.join(temp.path, 'none'),
        environment: const {},
      ),
      probe: FolderProbe(pm, os),
      jobs: 4,
      client: MockClient((r) async {
        requested.add(r.url);
        if (r.url.path == '/releases/index.php') {
          return http.Response(json, 200);
        }
        return http.Response.bytes(_tarball, 200);
      }),
      retryDelay: Duration.zero,
    );
  }

  ProcessSpec step(String executable, [String? first]) =>
      pm.interactive.firstWhere(
        (s) =>
            s.executable == executable &&
            (first == null || s.arguments.first == first),
      );

  Future<void> seedSlot(
    String version, {
    SlotKind kind = SlotKind.source,
  }) async {
    final php = File(p.join(prefix, 'bin', 'php'));
    await php.create(recursive: true);
    await php.writeAsString('old');
    await InstallRecord(
      version: version,
      sourceUrl: '',
      archiveSha256: '',
      verified: true,
      installedAt: DateTime(2026),
      files: const {},
      kind: kind,
    ).writeTo(prefix);
  }

  test('install 8.4 verifies the php.net tarball, builds into staging and '
      'commits a source record with php-config', () async {
    final result = await installer().install('8.4');

    expect(result.version, '8.4.27');
    expect(
      requested.first.toString(),
      'https://www.php.net/releases/index.php?json&version=8.4',
    );
    expect(
      requested[1].toString(),
      'https://www.php.net/distributions/php-8.4.27.tar.xz',
    );

    final tar = pm.captured.firstWhere((s) => s.executable == 'tar');
    expect(tar.arguments.take(1), ['-xJf']);
    final buildDir = tar.arguments[3];
    expect(p.isWithin(versions, buildDir), isFalse);

    final configure = step(p.join(buildDir, 'php-8.4.27', 'configure'));
    expect(configure.workingDirectory, p.join(buildDir, 'php-8.4.27'));
    expect(configure.arguments, [
      '--prefix=$prefix',
      '--with-config-file-path=${p.join(prefix, 'etc')}',
      '--with-config-file-scan-dir=${p.join(prefix, 'etc', 'conf.d')}',
      ...sourceConfigureFlags,
    ]);
    expect(sourceConfigureFlags, contains('--enable-opcache'));
    expect(step('make').arguments, ['-j4']);
    expect(step('make', 'install').arguments, [
      'install',
      'INSTALL_ROOT=${staging()}',
    ]);
    expect(
      console.printed,
      contains('Building PHP 8.4.27 from source (about 5 minutes)...'),
    );

    final record = (await InstallRecord.readFrom(prefix))!;
    expect(record.kind, SlotKind.source);
    expect(record.version, '8.4.27');
    expect(record.verified, isTrue);
    expect(record.archiveSha256, _sha);
    expect(record.phpConfig, p.join(prefix, 'bin', 'php-config'));
    expect(record.prefix, prefix);
    expect(record.writable, isTrue);
    expect(configure.environment, isNull); // Linux: inherited as is
    expect(File(p.join(prefix, 'bin', 'php')).readAsStringSync(), 'php');
    expect(Directory(staging()).existsSync(), isFalse);
    expect(Directory(buildDir).existsSync(), isFalse);
  });

  test('a --force reinstall records writable from the new tree', () async {
    await seedSlot('8.4.27');
    await installer().install(
      '8.4',
      options: const InstallOptions(force: true),
    );
    final record = (await InstallRecord.readFrom(prefix))!;
    expect(record.kind, SlotKind.source);
    expect(record.writable, isTrue);
    expect(File(p.join(prefix, 'bin', 'php')).readAsStringSync(), 'php');
  });

  test('macOS: keg-only brew prefixes reach pkg-config, configure and make '
      'through the child env only', () async {
    await installer(platform: MacOSPlatformInfo()).install('8.4');

    const dir = '/opt/homebrew/opt/openssl@3/lib/pkgconfig';
    final pkgConfig = pm.captured.firstWhere(
      (s) => s.executable == 'pkg-config',
    );
    expect(pkgConfig.environment?['PKG_CONFIG_PATH'], dir);
    for (final spec in pm.interactive) {
      expect(spec.environment?['PKG_CONFIG_PATH'], dir);
    }
    expect(Platform.environment['PKG_CONFIG_PATH'] ?? '', isNot(contains(dir)));
  });

  test('an exact patch asks php.net for that version', () async {
    await installer(patch: '26').install('8.4.26');
    expect(
      requested.first.toString(),
      'https://www.php.net/releases/index.php?json&version=8.4.26',
    );
  });

  test('a checksum mismatch stops before the build', () async {
    await expectLater(
      installer(sha: 'a' * 64).install('8.4'),
      throwsA(isA<Exception>()),
    );
    expect(pm.interactive, isEmpty);
    expect(Directory(prefix).existsSync(), isFalse);
  });

  test(
    'no published sha256 needs --allow-unverified; the hash is recorded',
    () async {
      await expectLater(
        installer(sha: null).install('8.4'),
        throwsA(isA<UnverifiedReleaseException>()),
      );
      expect(pm.interactive, isEmpty);

      await installer(
        sha: null,
      ).install('8.4', options: const InstallOptions(allowUnverified: true));
      final record = (await InstallRecord.readFrom(prefix))!;
      expect(record.verified, isFalse);
      expect(record.archiveSha256, _sha);
    },
  );

  test('a make failure leaves the old versions/8.4 untouched', () async {
    await seedSlot('8.4.27');
    final before = await InstallRecord.hashTree(prefix);
    pm.failOn = '-j4';

    await expectLater(
      installer().install('8.4', options: const InstallOptions(force: true)),
      throwsA(isA<Exception>()),
    );

    expect(await InstallRecord.hashTree(prefix), before);
    expect(Directory(staging()).existsSync(), isFalse);
    final buildDir = pm.captured
        .firstWhere((s) => s.executable == 'tar')
        .arguments[3];
    expect(Directory(buildDir).existsSync(), isFalse);
  });

  test('a different patch in the slot is SlotFilledException', () async {
    await seedSlot('8.4.26');
    await expectLater(
      installer().install('8.4', options: const InstallOptions(force: true)),
      throwsA(isA<SlotFilledException>()),
    );
    expect(pm.interactive, isEmpty);
  });

  test('--force turns a static slot of an older patch into a source slot '
      '(R30)', () async {
    await seedSlot('8.4.27', kind: SlotKind.static);
    await installer(
      patch: '28',
    ).install('8.4', options: const InstallOptions(force: true));
    final record = (await InstallRecord.readFrom(prefix))!;
    expect(record.kind, SlotKind.source);
    expect(record.version, '8.4.28');
  });

  test('another kind without --force is still SlotFilledException', () async {
    await seedSlot('8.4.27', kind: SlotKind.static);
    await expectLater(
      installer(patch: '28').install('8.4'),
      throwsA(isA<SlotFilledException>()),
    );
  });

  test('the same patch is already installed without --force', () async {
    await seedSlot('8.4.27');
    final result = await installer().install('8.4');
    expect(result.alreadyInstalled, isTrue);
    expect(pm.interactive, isEmpty);
  });

  test('missing build tools stop before the download', () async {
    final missing = BuildTools(
      _MissingPm(),
      LinuxPlatformInfo(),
      osReleasePath: p.join(temp.path, 'none'),
    );
    final i = SourceBuildInstaller(
      versionsPath: versions,
      platform: LinuxPlatformInfo(),
      console: console,
      processManager: pm,
      buildTools: missing,
      jobs: 1,
      client: MockClient((r) async {
        requested.add(r.url);
        return http.Response(
          jsonEncode({
            'version': '8.4.27',
            'source': [
              {'filename': 'php-8.4.27.tar.xz', 'sha256': _sha},
            ],
          }),
          200,
        );
      }),
    );
    await expectLater(i.install('8.4'), throwsA(isA<MissingToolsException>()));
    expect(requested, hasLength(1)); // the JSON, not the tarball
  });
}

class _MissingPm implements IProcessManager {
  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async =>
      const CapturedProcessResult(stdout: '', stderr: '', exitCode: 1);

  @override
  Future<int> runInteractive(ProcessSpec spec) => throw UnimplementedError();

  @override
  Future<String> resolveSystemCommand(String command) async => command;
}
