import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pvm/src/commands/ext_command.dart';
import 'package:pvm/src/core/active_version_resolver.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/core/symlink_inspector.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/version_registry.dart';
import 'package:pvm/src/services/build_tools.dart';
import 'package:pvm/src/services/extensions/extension_artifact.dart';
import 'package:pvm/src/services/extensions/pecl_source_builder.dart';
import 'package:test/test.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

/// Plays php (`-m`, `--ini`), php-config, sh, tar and make; records runs.
class _Pm implements IProcessManager {
  String modules = '[PHP Modules]\nCore\n';
  String scanDir = '(none)'; // `php --ini` scan dir
  String prefix = ''; // `php-config --prefix`
  final captured = <ProcessSpec>[];
  final interactive = <ProcessSpec>[];

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    captured.add(spec);
    final exe = spec.executable;
    var out = '';
    if (exe == 'tar') {
      final dest = spec.arguments[spec.arguments.indexOf('-C') + 1];
      final tgz = p.basenameWithoutExtension(spec.arguments[1]);
      Directory(p.join(dest, tgz)).createSync(recursive: true);
    } else if (p.basename(exe).startsWith('php-config')) {
      out = '$prefix\n';
    } else if (spec.arguments.contains('--ini')) {
      out =
          'Configuration File (php.ini) Path: /etc\n'
          'Scan for additional .ini files in: $scanDir\n';
    } else if (spec.arguments.contains('-m')) {
      final enabled = File(p.join(scanDir, '50-xdebug.ini')).existsSync();
      out = '$modules${enabled ? 'Xdebug\n' : ''}';
    }
    return CapturedProcessResult(stdout: out, stderr: '', exitCode: 0);
  }

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    interactive.add(spec);
    if (spec.executable == 'make') {
      File(p.join(spec.workingDirectory!, 'modules', 'xdebug.so'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2]);
    }
    return 0;
  }

  @override
  Future<String> resolveSystemCommand(String command) async => command;
}

void _write(String path, InstallRecord rec) =>
    File(path).writeAsStringSync(jsonEncode(rec.toJson()));

const _entry = ExtensionEntry(
  name: 'xdebug',
  version: '3.5.3',
  file: 'xdebug.so',
  sha256: 'abc',
  verified: false,
);

void main() {
  late Directory temp;
  late MockOSManager os;
  late MockConsole console;
  late _Pm pm;
  late PlatformInfo platform;
  late List<String> calls; // 'source 8.4', 'dll 8.4', 'dispose'
  late Future<ExtensionEntry> Function() routeResult;
  late String scanDir;
  String? passedConfDir;
  ExtensionRoute Function()? realSource;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pvm_ext_cmd_');
    final project = Directory(p.join(temp.path, 'project'))..createSync();
    // Pins the project root so the walk-up never reaches a real ~/.pvm.
    File(p.join(project.path, '.pvmrc')).writeAsStringSync('8.3');
    os = MockOSManager()
      ..mockProgramDir = p.join(temp.path, 'pvm')
      ..mockHomeDir = p.join(temp.path, 'home')
      ..mockCurrentDirectory = project.path
      ..mockEnvironment = {}
      ..mockVersions = [];
    os.setDirectoryExistsResult(os.phpVersionsPath, true);
    console = MockConsole();
    pm = _Pm();
    platform = LinuxPlatformInfo();
    calls = [];
    routeResult = () async => _entry;
    scanDir = p.join(temp.path, 'scan');
    Directory(scanDir).createSync();
    pm.scanDir = scanDir;
    passedConfDir = null;
    realSource = null;
  });

  tearDown(() async {
    // Remove links first so a recursive delete never follows one.
    final versions = Directory(os.phpVersionsPath);
    if (versions.existsSync()) {
      for (final e in versions.listSync(followLinks: false)) {
        if (e is Link) e.deleteSync();
      }
    }
    await temp.delete(recursive: true);
  });

  InstallRecord record(
    String version,
    SlotKind kind, {
    bool writable = true,
    String? phpConfig,
    String? prefix,
    List<ExtensionEntry> extensions = const [],
    String? extensionDir,
  }) => InstallRecord(
    version: version,
    sourceUrl: '',
    archiveSha256: '',
    verified: true,
    installedAt: DateTime.utc(2026),
    files: const {},
    kind: kind,
    writable: writable,
    phpConfig: phpConfig,
    prefix: prefix,
    extensionDir: extensionDir ?? '/x/ext',
    extensions: extensions,
  );

  String slotPath(String x) => p.join(os.phpVersionsPath, x);

  void addSlot(String x, InstallRecord? rec) {
    Directory(slotPath(x)).createSync(recursive: true);
    if (rec != null) _write(p.join(slotPath(x), InstallRecord.fileName), rec);
    os.mockVersions.add(x);
    os.setDirectoryExistsResult(slotPath(x), true);
  }

  /// `versions/<x>` links to a user folder; its record sits beside the link.
  String addLinked(String x, InstallRecord rec) {
    final folder = p.join(temp.path, 'user-php-$x');
    Directory(folder).createSync(recursive: true);
    Directory(os.phpVersionsPath).createSync(recursive: true);
    Link(slotPath(x)).createSync(folder);
    _write(p.join(os.phpVersionsPath, '$x.pvm-link.json'), rec);
    os.mockVersions.add(x);
    os.setDirectoryExistsResult(slotPath(x), true);
    return folder;
  }

  void wire(String link, String x) =>
      os.symlinkTargets[p.join(link, '.pvm')] = slotPath(x);

  ExtensionRoute route(String name) => (
    install: (String ext, InstalledSlot slot, {String? confDir}) {
      calls.add('$name ${slot.version.slot}');
      passedConfDir = confDir;
      return routeResult();
    },
    dispose: () => calls.add('dispose'),
  );

  Future<int> run(List<String> args) async {
    final runner = CommandRunner<int>('pvm', 'test')
      ..addCommand(
        ExtCommand(
          ExtInstallCommand(
            osManager: os,
            resolver: ActiveVersionResolver(SymLinkInspector(os)),
            processManager: pm,
            platform: platform,
            console: console,
            sourceBuilder: realSource ?? () => route('source'),
            windowsDll: () => route('dll'),
          ),
        ),
      );
    try {
      return await runner.run(['ext', 'install', ...args]) ?? 0;
    } on UsageException catch (e) {
      console.errors.add(e.message);
      return ExitCode.usageError; // as runPvm maps it
    }
  }

  Future<InstallRecord?> saved(String x) =>
      VersionRegistry.readSlotRecord(slotPath(x));

  test('exit codes for extension failures', () {
    expect(ExitCode.toolMissing, 7);
    expect(ExitCode.extensionUnavailable, 8);
    expect(ExitCode.slotInUse, 9);
    expect(ExitCode.buildFailed, 10);
  });

  test('without --version targets local 8.3 over global 8.4', () async {
    addSlot('8.3', record('8.3.10', SlotKind.source));
    addSlot('8.4', record('8.4.27', SlotKind.source));
    wire(os.mockCurrentDirectory!, '8.3');
    wire(os.mockHomeDir, '8.4');

    expect(await run(['xdebug']), ExitCode.success);
    expect(calls, ['source 8.3', 'dispose']);
  });

  test('without --version or any active version it errors', () async {
    addSlot('8.4', record('8.4.27', SlotKind.source));
    expect(await run(['xdebug']), ExitCode.configurationError);
    expect(console.errors.join('\n'), contains('--version'));
    expect(calls, isEmpty);
  });

  test('already in php -m: says so and exits 0 without a route', () async {
    addSlot('8.4', record('8.4.27', SlotKind.source));
    pm.modules = '[PHP Modules]\nCore\n\n[Zend Modules]\nXdebug\n';

    expect(await run(['xdebug', '--version=8.4']), ExitCode.success);
    expect(console.printed, ['xdebug is already enabled for 8.4 (8.4.27)']);
    expect(calls, isEmpty);
    expect(
      pm.captured.single.executable,
      p.join(slotPath('8.4'), 'bin', 'php'),
    );
    expect(pm.captured.single.arguments, ['-m']);
  });

  test('windows-zip calls PeclWindowsDll', () async {
    platform = WindowsPlatformInfo();
    addSlot('8.4', record('8.4.27', SlotKind.windowsZip));
    expect(await run(['xdebug', '--version=8.4']), ExitCode.success);
    expect(calls, ['dll 8.4', 'dispose']);
  });

  test('source calls PeclSourceBuilder and records the entry', () async {
    final old = ExtensionEntry(
      name: 'xdebug',
      version: '3.4.0',
      file: 'xdebug.so',
      sha256: 'old',
      verified: false,
    );
    const other = ExtensionEntry(
      name: 'redis',
      version: '6.0.0',
      file: 'redis.so',
      sha256: 'r',
      verified: false,
    );
    addSlot('8.4', record('8.4.27', SlotKind.source, extensions: [old, other]));

    expect(await run(['xdebug', '--version=8.4']), ExitCode.success);
    expect(calls, ['source 8.4', 'dispose']);
    expect((await saved('8.4'))!.extensions, [other, _entry]);
  });

  test('--version accepts the slot recorded patch', () async {
    addSlot('8.4', record('8.4.27', SlotKind.source));
    expect(await run(['xdebug', '--version=8.4.27']), ExitCode.success);
    expect(calls, ['source 8.4', 'dispose']);
  });

  test('linked + writable + php-config calls PeclSourceBuilder and writes '
      'the link record', () async {
    addLinked(
      '8.4',
      record(
        '8.4.27',
        SlotKind.linked,
        phpConfig: '/home/u/php/bin/php-config',
        prefix: '/home/u/php',
      ),
    );
    expect(await run(['xdebug', '--version=8.4']), ExitCode.success);
    expect(calls, ['source 8.4', 'dispose']);
    expect(passedConfDir, scanDir);
    expect((await saved('8.4'))!.extensions, [_entry]);
  });

  test('linked + writable without php-config refuses', () async {
    final folder = addLinked('8.4', record('8.4.27', SlotKind.linked));
    expect(await run(['xdebug', '--version=8.4']), ExitCode.generalError);
    expect(console.errors, [
      "xdebug can't be built for 8.4: $folder has no php-config",
    ]);
    expect(calls, isEmpty);
  });

  test('linked, not writable, ondrej/sury /usr prints apt', () async {
    addLinked(
      '8.4',
      record(
        '8.4.27',
        SlotKind.linked,
        writable: false,
        phpConfig: '/usr/bin/php-config8.4',
        prefix: '/usr',
      ),
    );
    expect(await run(['xdebug', '--version=8.4']), ExitCode.toolMissing);
    expect(console.printed, contains('sudo apt install php8.4-xdebug'));
    expect(calls, isEmpty);
  });

  test('linked, not writable, Plesk prefix prints its pecl', () async {
    addLinked(
      '8.4',
      record(
        '8.4.27',
        SlotKind.linked,
        writable: false,
        phpConfig: '/opt/plesk/php/8.4/bin/php-config',
        prefix: '/opt/plesk/php/8.4',
      ),
    );
    expect(await run(['xdebug', '--version=8.4']), ExitCode.toolMissing);
    expect(
      console.printed,
      contains('/opt/plesk/php/8.4/bin/pecl install xdebug'),
    );
  });

  test('linked, not writable, Remi and cPanel prefixes', () async {
    expect(
      systemInstallCommand('/opt/remi/php84/root/usr', '8.4', 'xdebug'),
      'sudo dnf install php84-php-pecl-xdebug',
    );
    expect(
      systemInstallCommand('/opt/cpanel/ea-php84/root/usr', '8.4', 'xdebug'),
      '/opt/cpanel/ea-php84/root/usr/bin/pecl install xdebug',
    );
  });

  test('linked on Windows: writable calls PeclWindowsDll', () async {
    platform = WindowsPlatformInfo();
    addLinked('8.4', record('8.4.27', SlotKind.linked));
    expect(await run(['xdebug', '--version=8.4']), ExitCode.success);
    expect(calls, ['dll 8.4', 'dispose']);
    expect(passedConfDir, scanDir);
    expect(
      pm.captured.last.executable,
      p.join(temp.path, 'user-php-8.4', 'php.exe'),
    );
  });

  test('linked on Windows: not writable says install it there', () async {
    platform = WindowsPlatformInfo();
    final folder = addLinked(
      '8.4',
      record('8.4.27', SlotKind.linked, writable: false),
    );
    expect(await run(['xdebug', '--version=8.4']), ExitCode.toolMissing);
    expect(console.errors, [
      '$folder is not writable; install xdebug there yourself',
    ]);
    expect(calls, isEmpty);
  });

  group('linked ini scan dir (R24)', () {
    late String folder;
    late List<Uri> requested;

    setUp(() {
      folder = p.join(temp.path, 'user-php-8.4');
      for (final n in ['php', 'php-config', 'phpize']) {
        File(p.join(folder, 'bin', n)).createSync(recursive: true);
      }
      addLinked(
        '8.4',
        record(
          '8.4.27',
          SlotKind.linked,
          phpConfig: p.join(folder, 'bin', 'php-config'),
          prefix: folder,
          extensionDir: p.join(folder, 'lib', 'ext'),
        ),
      );
      pm.prefix = folder;
      requested = [];
      realSource = () {
        final b = PeclSourceBuilder(
          platform: platform,
          console: console,
          processManager: pm,
          buildTools: BuildTools(
            pm,
            platform,
            osReleasePath: p.join(temp.path, 'none'),
            environment: const {},
          ),
          jobs: 1,
          client: MockClient((r) async {
            requested.add(r.url);
            return r.url.path.endsWith('stable.txt')
                ? http.Response('3.5.3\n', 200)
                : http.Response.bytes(utf8.encode('tgz'), 200);
          }),
          retryDelay: Duration.zero,
        );
        return (install: b.install, dispose: b.dispose);
      };
    });

    test('full install enables it in the folder PHP scan dir', () async {
      expect(await run(['xdebug', '--version=8.4']), ExitCode.success);
      final ini = File(p.join(scanDir, '50-xdebug.ini'));
      expect(
        ini.readAsStringSync(),
        'extension=${p.join(folder, 'lib', 'ext', 'xdebug.so')}\n',
      );
      expect(
        File(p.join(folder, 'lib', 'ext', 'xdebug.so')).existsSync(),
        isTrue,
      );
      final entries = (await saved('8.4'))!.extensions;
      expect(entries.map((e) => '${e.name} ${e.version}'), ['xdebug 3.5.3']);
      expect(
        File(p.join(os.phpVersionsPath, '8.4.pvm-link.json')).existsSync(),
        isTrue,
      );
    });

    for (final (name, dir) in [
      ('(none)', () => '(none)'),
      ('missing', () => p.join(temp.path, 'gone')),
    ]) {
      test('scan dir $name: refused before any build or download', () async {
        pm.scanDir = dir();
        expect(await run(['xdebug', '--version=8.4']), ExitCode.toolMissing);
        expect(console.errors, [
          "$folder's PHP has no writable ini scan dir; "
              'install xdebug there yourself',
        ]);
        expect(pm.interactive, isEmpty);
        expect(requested, isEmpty);
      });
    }
  });

  test('static refuses with the exact message', () async {
    addSlot('8.4', record('8.4.27', SlotKind.static));
    expect(await run(['xdebug', '--version=8.4']), ExitCode.generalError);
    expect(console.errors, [
      "xdebug isn't in this build. Run: pvm install 8.4 --from-source --force, "
          'or pvm link 8.4 <folder>',
    ]);
    expect(calls, isEmpty);
  });

  test('--version=8.1 not installed lists the slots', () async {
    addSlot('8.3', record('8.3.10', SlotKind.source));
    addSlot('8.4', record('8.4.27', SlotKind.source));
    expect(await run(['xdebug', '--version=8.1']), ExitCode.versionNotFound);
    final err = console.errors.join('\n');
    expect(err, contains('8.1'));
    expect(err, contains('8.4 (8.4.27), 8.3 (8.3.10)'));
    expect(calls, isEmpty);
  });

  test('--version with another patch is not installed', () async {
    addSlot('8.4', record('8.4.27', SlotKind.source));
    expect(await run(['xdebug', '--version=8.4.1']), ExitCode.versionNotFound);
  });

  test('a slot without a record is refused', () async {
    addSlot('8.4', null);
    expect(await run(['xdebug', '--version=8.4']), ExitCode.generalError);
    expect(console.errors.join(), contains('pvm link 8.4'));
    expect(calls, isEmpty);
  });

  test('ext install ../x is a usage error before anything runs', () async {
    addSlot('8.4', record('8.4.27', SlotKind.source));
    expect(await run(['../x', '--version=8.4']), ExitCode.usageError);
    expect(pm.captured, isEmpty);
    expect(calls, isEmpty);
  });

  test('MissingToolsException prints its install command, exit 7', () async {
    addSlot('8.4', record('8.4.27', SlotKind.source));
    routeResult = () async => throw const MissingToolsException([
      'autoconf',
    ], 'sudo apt install autoconf');
    expect(await run(['xdebug', '--version=8.4']), ExitCode.toolMissing);
    expect(console.printed, contains('sudo apt install autoconf'));
    expect(calls, ['source 8.4', 'dispose']);
    expect((await saved('8.4'))!.extensions, isEmpty);
  });

  test('ExtensionUnavailableException exits 8', () async {
    addSlot('8.4', record('8.4.27', SlotKind.source));
    routeResult = () async =>
        throw const ExtensionUnavailableException('no build');
    expect(
      await run(['xdebug', '--version=8.4']),
      ExitCode.extensionUnavailable,
    );
    expect(console.errors, ['no build']);
    expect(calls.last, 'dispose');
  });

  test('a load or build failure exits 10; a broken slot exits 1', () async {
    addSlot('8.4', record('8.4.27', SlotKind.source));
    routeResult = () async => throw ExtensionLoadException('xdebug', 'boom');
    expect(await run(['xdebug', '--version=8.4']), ExitCode.buildFailed);
    routeResult = () async =>
        throw const ExtensionBuildException('make failed (exit 2)');
    expect(await run(['xdebug', '--version=8.4']), ExitCode.buildFailed);
    routeResult = () async => throw const SlotBrokenException('broken');
    expect(await run(['xdebug', '--version=8.4']), ExitCode.generalError);
  });
}
