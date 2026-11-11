import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pvm/src/commands/ext_command.dart';
import 'package:pvm/src/commands/update_command.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/domain/exceptions/extension_build_exception.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/domain/php_release.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/version_registry.dart';
import 'package:pvm/src/interfaces/i_installer.dart';
import 'package:pvm/src/interfaces/i_release_source.dart';
import 'package:pvm/src/managers/static_php_installer.dart';
import 'package:pvm/src/managers/windows_installer.dart';
import 'package:pvm/src/services/release_fetcher.dart';
import 'package:pvm/src/services/slot_ini.dart';
import 'package:test/test.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_installer.dart';
import '../mocks/mock_os_manager.dart';

/// `php -m` lists every `50-<ext>.ini` in PHP_INI_SCAN_DIR except [broken].
class _Pm implements IProcessManager {
  final broken = <String>{};
  final captured = <ProcessSpec>[];
  String? probe; // FolderProbe's `php -n -r` JSON

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    captured.add(spec);
    if (probe != null && spec.arguments.contains('-r')) {
      return CapturedProcessResult(stdout: probe!, stderr: '', exitCode: 0);
    }
    final scan = Directory(spec.environment?['PHP_INI_SCAN_DIR'] ?? '');
    final loaded = [
      if (scan.existsSync())
        for (final f in scan.listSync())
          if (RegExp(r'^50-(.+)\.ini$').firstMatch(p.basename(f.path))
              case final m?)
            if (!broken.contains(m[1])) m[1]!,
    ];
    return CapturedProcessResult(
      stdout: '[PHP Modules]\nCore\n${loaded.join('\n')}\n',
      stderr: '',
      exitCode: 0,
    );
  }

  @override
  Future<int> runInteractive(ProcessSpec spec) async => 0;

  @override
  Future<String> resolveSystemCommand(String command) async => command;
}

class _Fetcher implements IReleaseFetcher {
  final List<PhpRelease> releases;
  _Fetcher(this.releases);

  @override
  String get platformName => 'test';

  @override
  Future<List<PhpRelease>> fetchReleases() async => releases;
}

class _Source implements IReleaseSource {
  final List<int> tgz;
  bool published = true; // false: no published SHA-256
  _Source(this.tgz);

  @override
  String get name => 'test';

  @override
  Future<PhpRelease> resolve(
    PhpVersion version, {
    required Architecture architecture,
    required BuildType buildType,
  }) async => _release(
    '${version.slot}.27',
    'https://dl.static-php.dev/v3/php-bin/bulk/'
        'php-${version.slot}.27-cli-linux-x86_64.tar.gz',
    tgz,
    published: published,
  );
}

PhpRelease _release(
  String v,
  String url,
  List<int> bytes, {
  bool published = true,
}) {
  final parsed = PhpVersion.parse(v);
  return PhpRelease(
    versionString: v,
    major: parsed.major,
    minor: parsed.minor,
    patch: parsed.patch!,
    architecture: Architecture.x64,
    buildType: BuildType.nts,
    downloadUrl: url,
    sha256: published ? crypto.sha256.convert(bytes).toString() : '',
    sizeBytes: bytes.length,
    lastModified: DateTime(2026),
  );
}

List<int> _zip(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach((name, data) => archive.addFile(ArchiveFile.bytes(name, data)));
  return ZipEncoder().encodeBytes(archive);
}

/// Records how it was called; [onInstall] plays the installer.
class _Installer extends MockInstaller {
  final Future<InstallResult> Function(InstallOptions? options) onInstall;
  int calls = 0;
  _Installer(this.onInstall);

  @override
  Future<InstallResult> install(String version, {InstallOptions? options}) {
    calls++;
    return onInstall(options);
  }
}

ExtensionEntry _ext(String name, [String version = '3.4.0']) => ExtensionEntry(
  name: name,
  version: version,
  file: '$name.so',
  sha256: 'abc',
  verified: false,
);

void main() {
  late Directory temp;
  late MockOSManager os;
  late MockConsole console;
  late _Pm pm;
  late PlatformInfo platform;
  late IInstaller installer;
  IInstaller? sourceInstaller;
  late ExtensionRoute Function() sourceBuilder;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pvm_update_cmd_');
    os = MockOSManager()
      ..mockProgramDir = p.join(temp.path, 'pvm')
      ..mockHomeDir = p.join(temp.path, 'home')
      ..mockEnvironment = {}
      ..mockVersions = [];
    os.setDirectoryExistsResult(os.phpVersionsPath, true);
    console = MockConsole();
    pm = _Pm();
    platform = WindowsPlatformInfo();
    installer = _Installer((_) => fail('installer must not run'));
    sourceInstaller = null;
    sourceBuilder = () => fail('no extension rebuild expected');
  });

  tearDown(() async {
    final versions = Directory(os.phpVersionsPath);
    if (versions.existsSync()) {
      for (final e in versions.listSync(followLinks: false)) {
        if (e is Link) e.deleteSync();
      }
    }
    await temp.delete(recursive: true);
  });

  String slotPath(String x) => p.join(os.phpVersionsPath, x);

  InstallRecord record(
    String version,
    SlotKind kind, {
    Map<String, String> files = const {},
    List<ExtensionEntry> extensions = const [],
  }) => InstallRecord(
    version: version,
    sourceUrl: '',
    archiveSha256: '',
    verified: true,
    installedAt: DateTime.utc(2026),
    files: files,
    kind: kind,
    apiNo: '20240924',
    extensionDir: p.join(slotPath('8.4'), 'ext'),
    extensions: extensions,
  );

  /// `versions/<x>` with [tree] (relative path → bytes) and [rec].
  Future<void> addSlot(
    String x,
    InstallRecord rec, [
    Map<String, List<int>> tree = const {},
  ]) async {
    for (final e in tree.entries) {
      File(p.join(slotPath(x), e.key))
        ..createSync(recursive: true)
        ..writeAsBytesSync(e.value);
    }
    Directory(slotPath(x)).createSync(recursive: true);
    await rec.writeTo(slotPath(x));
    os.mockVersions.add(x);
    os.setDirectoryExistsResult(slotPath(x), true);
  }

  Future<int> run(List<String> args) async {
    final runner = CommandRunner<int>('pvm', 'test')
      ..addCommand(
        UpdateCommand(
          osManager: os,
          installer: installer,
          sourceInstaller: sourceInstaller,
          processManager: pm,
          platform: platform,
          console: console,
          sourceBuilder: sourceBuilder,
        ),
      );
    try {
      return await runner.run(['update', ...args]) ?? 0;
    } on UsageException catch (e) {
      console.errors.add(e.message);
      return ExitCode.usageError; // as runPvm maps it
    }
  }

  List<int> bytes(String x, String rel) =>
      File(p.join(slotPath(x), rel)).readAsBytesSync();

  List<String> leftovers() => [
    for (final e in Directory(os.phpVersionsPath).listSync())
      if (p.basename(e.path).startsWith('.')) p.basename(e.path),
  ];

  test(
    'a v1 TS x86 record is probed first, so update keeps TS x86 (R29)',
    () async {
      InstallOptions? asked;
      installer = _Installer((o) async {
        asked = o;
        return const InstallResult('8.4.26', alreadyInstalled: true);
      });
      final dir = Directory(slotPath('8.4'))..createSync(recursive: true);
      File(p.join(dir.path, 'php.exe')).writeAsBytesSync([1]);
      File(p.join(dir.path, InstallRecord.fileName)).writeAsStringSync(
        '{"schema":1,"version":"8.4.26","sourceUrl":"u","archiveSha256":"a",'
        '"verified":true,"installedAt":"2025-01-01T00:00:00.000Z","files":{}}',
      );
      os.mockVersions.add('8.4');
      os.setDirectoryExistsResult(slotPath('8.4'), true);
      pm.probe =
          '{"v":"8.4.26","zts":true,"arch":"x86","ext":"C:/php/ext",'
          '"build":"API20240924,TS,VS17"}';

      expect(await run(['8.4']), ExitCode.success);

      expect(asked!.buildType, BuildType.ts);
      expect(asked!.architecture, Architecture.x86);
      final saved = (await VersionRegistry.readSlotRecord(slotPath('8.4')))!;
      expect(saved.apiNo, '20240924');
      expect(saved.vsVersion, 'VS17');
    },
  );

  group('windows-zip', () {
    final newZip = _zip({
      'php.exe': [3],
      'ext/php_curl.dll': [4],
      'libdep.dll': [7], // the new archive now ships it
    });

    Future<void> seed() async {
      installer = WindowsInstaller(
        versionsPath: os.phpVersionsPath,
        releaseFetcher: _Fetcher([
          _release(
            '8.4.27',
            'https://windows.php.net/downloads/releases/php-8.4.27.zip',
            newZip,
          ),
        ]),
        console: console,
        client: MockClient((_) async => http.Response.bytes(newZip, 200)),
        retryDelay: Duration.zero,
      );
      await addSlot(
        '8.4',
        record(
          '8.4.26',
          SlotKind.windowsZip,
          files: const {'php.exe': 'h1', 'ext/php_curl.dll': 'h2'},
          extensions: [_ext('xdebug')],
        ),
        {
          'php.exe': [1],
          'ext/php_curl.dll': [2],
          'ext/php_xdebug.dll': [9],
          'libdep.dll': [8],
          'libssh2.dll': [6],
          'php.ini': [5],
          'conf.d/50-xdebug.ini': 'zend_extension=php_xdebug.dll\n'.codeUnits,
        },
      );
    }

    test('moves the slot to the newest patch, carrying user files', () async {
      await seed();

      expect(await run(['8.4']), ExitCode.success);

      expect(console.printed, contains('Updated 8.4 (8.4.26) → 8.4 (8.4.27)'));
      expect(bytes('8.4', 'php.exe'), [3]);
      expect(bytes('8.4', 'ext/php_curl.dll'), [4]);
      expect(bytes('8.4', 'ext/php_xdebug.dll'), [9]);
      expect(bytes('8.4', 'libssh2.dll'), [6]);
      expect(bytes('8.4', 'libdep.dll'), [7], reason: 'archive wins');
      expect(bytes('8.4', 'php.ini'), [5]);
      expect(
        File(p.join(slotPath('8.4'), 'conf.d', '50-xdebug.ini')).existsSync(),
        isTrue,
      );
      final saved = (await VersionRegistry.readSlotRecord(slotPath('8.4')))!;
      expect(saved.version, '8.4.27');
      expect(saved.kind, SlotKind.windowsZip);
      expect(saved.extensions, [_ext('xdebug')]);
      expect(leftovers(), isEmpty);

      // The load check ran on the staged PHP and its conf.d, before the swap.
      final staging = p.join(os.phpVersionsPath, '.staging-8.4-$pid');
      final check = pm.captured.single;
      expect(check.executable, p.join(staging, 'php.exe'));
      expect(check.environment!['PHP_INI_SCAN_DIR'], p.join(staging, 'conf.d'));
    });

    test('an extension that no longer loads aborts the update', () async {
      await seed();
      pm.broken.add('xdebug');

      expect(await run(['8.4']), ExitCode.buildFailed);

      expect(console.errors.join('\n'), contains('xdebug'));
      expect(bytes('8.4', 'php.exe'), [1]);
      expect(bytes('8.4', 'libdep.dll'), [8]);
      expect(
        (await VersionRegistry.readSlotRecord(slotPath('8.4')))!.version,
        '8.4.26',
      );
      expect(leftovers(), isEmpty);
    });
  });

  group('static', () {
    final tgz = GZipEncoder().encodeBytes(
      TarEncoder().encodeBytes(
        Archive()..addFile(ArchiveFile.bytes('php', [3])),
      ),
    );

    late _Source source;

    setUp(() {
      platform = LinuxPlatformInfo();
      source = _Source(tgz);
      installer = StaticPhpInstaller(
        versionsPath: os.phpVersionsPath,
        source: source,
        // chmod runs only on a Unix host, where it works on the temp file.
        platform: Platform.isWindows ? WindowsPlatformInfo() : platform,
        console: console,
        client: MockClient((_) async => http.Response.bytes(tgz, 200)),
        retryDelay: Duration.zero,
      );
    });

    test(
      'reinstalls the newest patch; extensions and php.ini carry over',
      () async {
        await addSlot(
          '8.4',
          record(
            '8.4.26',
            SlotKind.static,
            files: const {'bin/php': 'h'},
            extensions: [_ext('xdebug')],
          ),
          {
            'bin/php': [1],
            'etc/php.ini': 'memory_limit=1G\n'.codeUnits,
            'etc/conf.d/50-xdebug.ini': 'zend_extension=xdebug.so\n'.codeUnits,
          },
        );

        expect(await run(['8.4']), ExitCode.success);

        expect(
          console.printed,
          contains('Updated 8.4 (8.4.26) → 8.4 (8.4.27)'),
        );
        expect(bytes('8.4', 'bin/php'), [3]);
        expect(
          File(p.join(slotPath('8.4'), 'etc', 'php.ini')).readAsStringSync(),
          'memory_limit=1G\n',
        );
        final saved = (await VersionRegistry.readSlotRecord(slotPath('8.4')))!;
        expect(saved.version, '8.4.27');
        expect(saved.extensions, [_ext('xdebug')]);
        expect(leftovers(), isEmpty);
      },
    );

    test('an unverified newest patch needs --allow-unverified', () async {
      source.published = false;
      await addSlot(
        '8.4',
        record('8.4.26', SlotKind.static, files: const {'bin/php': 'h'}),
        {
          'bin/php': [1],
        },
      );

      expect(await run(['8.4']), ExitCode.generalError);
      expect(console.errors, [
        const UnverifiedReleaseException('8.4.27').toString(),
      ]);
      expect(bytes('8.4', 'bin/php'), [1]);

      expect(await run(['8.4', '--allow-unverified']), ExitCode.success);
      expect(bytes('8.4', 'bin/php'), [3]);
      expect(
        (await VersionRegistry.readSlotRecord(slotPath('8.4')))!.verified,
        isFalse,
      );
    });

    test('already newest: says so and changes nothing', () async {
      await addSlot('8.4', record('8.4.27', SlotKind.static), {
        'bin/php': [1],
      });

      expect(await run(['8.4']), ExitCode.success);

      expect(console.printed, ['8.4 (8.4.27) is up to date']);
      expect(bytes('8.4', 'bin/php'), [1]);
    });
  });

  group('source', () {
    late List<String> builds;

    setUp(() {
      platform = LinuxPlatformInfo();
      builds = [];
      // Plays SourceBuildInstaller: a fresh make install in staging (empty
      // php.ini and conf.d, as _createIni leaves them), the hook, the swap.
      sourceInstaller = _Installer((options) async {
        final staged = p.join(os.phpVersionsPath, '.staging-8.4-test');
        File(p.join(staged, 'etc', 'php.ini'))
          ..createSync(recursive: true)
          ..writeAsStringSync('');
        Directory(p.join(staged, 'etc', 'conf.d')).createSync();
        await record('8.4.27', SlotKind.source).writeTo(staged);
        await options!.update!(staged);
        Directory(slotPath('8.4')).deleteSync(recursive: true);
        Directory(staged).renameSync(slotPath('8.4'));
        return const InstallResult('8.4.27');
      });
      sourceBuilder = () => (
        install: (String ext, InstalledSlot slot, {String? confDir}) async {
          builds.add('$ext ${slot.version}');
          if (ext == 'xdebug') throw ExtensionBuildException('make failed');
          return _ext(ext, '6.0.0');
        },
        dispose: () => builds.add('dispose'),
      );
    });

    test('rebuilds PHP, then each recorded extension against it', () async {
      await addSlot(
        '8.4',
        record(
          '8.4.26',
          SlotKind.source,
          extensions: [_ext('xdebug'), _ext('redis')],
        ),
        {
          'bin/php': [1],
        },
      );

      expect(await run(['8.4']), ExitCode.success);

      expect(builds, ['xdebug 8.4.27', 'dispose', 'redis 8.4.27', 'dispose']);
      expect(
        console.warnings,
        contains('xdebug could not be rebuilt; run: pvm ext install xdebug'),
      );
      final saved = (await VersionRegistry.readSlotRecord(slotPath('8.4')))!;
      expect(saved.version, '8.4.27');
      expect(saved.extensions, [_ext('redis', '6.0.0')]);
      expect(console.printed, contains('Updated 8.4 (8.4.26) → 8.4 (8.4.27)'));
    });

    test(
      'keeps extension settings and a disabled extension stays disabled',
      () async {
        // Plays PeclSourceBuilder's ini write against the updated slot.
        sourceBuilder = () => (
          install: (String ext, InstalledSlot slot, {String? confDir}) async {
            await SlotIni(
              slot.path,
              slot.record!,
              platform,
            ).enable(ext, zend: ext == 'xdebug');
            return _ext(ext, '6.0.0');
          },
          dispose: () {},
        );
        await addSlot(
          '8.4',
          record(
            '8.4.26',
            SlotKind.source,
            extensions: [_ext('xdebug'), _ext('redis')],
          ),
          {
            'bin/php': [1],
            'etc/conf.d/50-xdebug.ini':
                'zend_extension=/old/xdebug.so\nxdebug.mode=debug\n'.codeUnits,
            'etc/conf.d/50-redis.ini.disabled':
                'extension=/old/redis.so\nredis.x=1\n'.codeUnits,
          },
        );

        expect(await run(['8.4']), ExitCode.success);

        final confD = p.join(slotPath('8.4'), 'etc', 'conf.d');
        final ext = p.join(slotPath('8.4'), 'ext');
        expect(
          File(p.join(confD, '50-xdebug.ini')).readAsStringSync(),
          'zend_extension=${p.join(ext, 'xdebug.so')}\nxdebug.mode=debug\n',
        );
        expect(
          File(p.join(confD, '50-redis.ini.disabled')).readAsStringSync(),
          'extension=${p.join(ext, 'redis.so')}\nredis.x=1\n',
        );
        expect(File(p.join(confD, '50-redis.ini')).existsSync(), isFalse);
      },
    );

    test('keeps the edited php.ini and custom conf.d inis', () async {
      final ini = [...'memory_limit=1G\r\n'.codeUnits, 0xE9];
      final custom = 'opcache.enable=1\n'.codeUnits;
      final old = 'zend_extension=old\n'.codeUnits;
      await addSlot(
        '8.4',
        record('8.4.26', SlotKind.source, extensions: [_ext('xdebug')]),
        {
          'bin/php': [1],
          'etc/php.ini': ini,
          'etc/conf.d/90-custom.ini': custom,
          'etc/conf.d/50-xdebug.ini': old,
          'etc/conf.d/50-xdebug.ini.disabled': old,
        },
      );

      expect(await run(['8.4']), ExitCode.success);

      expect(bytes('8.4', 'etc/php.ini'), ini);
      expect(bytes('8.4', 'etc/conf.d/90-custom.ini'), custom);
      final confD = p.join(slotPath('8.4'), 'etc', 'conf.d');
      expect(File(p.join(confD, '50-xdebug.ini')).existsSync(), isFalse);
      expect(
        File(p.join(confD, '50-xdebug.ini.disabled')).existsSync(),
        isFalse,
      );
    });
  });

  test('a linked slot is updated where it lives', () async {
    platform = LinuxPlatformInfo();
    final folder = p.join(temp.path, 'user-php');
    Directory(folder).createSync();
    Directory(os.phpVersionsPath).createSync(recursive: true);
    Link(slotPath('8.4')).createSync(folder);
    await record(
      '8.4.26',
      SlotKind.linked,
    ).writeToFile(p.join(os.phpVersionsPath, '8.4.pvm-link.json'));
    os.mockVersions.add('8.4');

    expect(await run(['8.4']), ExitCode.generalError);

    expect(console.errors, ['8.4 is linked to $folder; update it there.']);
  });

  test('a slot in use maps to exit 9 and the exact message', () async {
    await addSlot('8.2', record('8.2.20', SlotKind.windowsZip), {
      'php.exe': [1],
    });
    installer = _Installer((_) => throw const SlotInUseException('8.2'));

    expect(await run(['8.2']), ExitCode.slotInUse);

    expect(console.errors, [
      'PHP 8.2 is in use (a running php.exe or web server holds its files). '
          'Stop it, then run: pvm update 8.2',
    ]);
  });

  test('a version that is not installed lists the slots', () async {
    await addSlot('8.4', record('8.4.26', SlotKind.windowsZip));

    expect(await run(['8.3']), ExitCode.versionNotFound);

    expect(console.errors.single, contains('Installed: 8.4 (8.4.26)'));
  });

  test('a full patch is a usage error', () async {
    await addSlot('8.4', record('8.4.26', SlotKind.windowsZip));

    expect(await run(['8.4.27']), ExitCode.usageError);
  });
}
