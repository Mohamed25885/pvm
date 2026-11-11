import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/services/build_tools.dart';
import 'package:test/test.dart';

/// `sh -c 'command -v "$1"' sh <tool>` and `pkg-config --exists <module>`
/// succeed unless the tool/module is listed as missing.
class _Pm implements IProcessManager {
  final Set<String> missing;
  final specs = <ProcessSpec>[];
  final Map<String, String> brew;
  _Pm([this.missing = const {}, this.brew = const {}]);

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    specs.add(spec);
    final name = spec.arguments.last;
    if (spec.executable == 'brew') {
      final prefix = brew[name];
      return CapturedProcessResult(
        stdout: prefix ?? '',
        stderr: '',
        exitCode: prefix == null ? 1 : 0,
      );
    }
    return CapturedProcessResult(
      stdout: '',
      stderr: '',
      exitCode: missing.contains(name) ? 1 : 0,
    );
  }

  @override
  Future<int> runInteractive(ProcessSpec spec) => throw UnimplementedError();

  @override
  Future<String> resolveSystemCommand(String command) async => command;
}

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('pvm_bt_'));
  tearDown(() async => temp.delete(recursive: true));

  Future<MissingToolsException> missingFor(
    String? osRelease, {
    Set<String> missing = const {'re2c'},
    PlatformInfo? platform,
    List<String> devPackages = const [],
  }) async {
    final path = p.join(temp.path, 'os-release');
    if (osRelease != null) File(path).writeAsStringSync(osRelease);
    final tools = BuildTools(
      _Pm(missing),
      platform ?? LinuxPlatformInfo(),
      osReleasePath: path,
    );
    try {
      await tools.require(['make', 're2c'], devPackages: devPackages);
    } on MissingToolsException catch (e) {
      return e;
    }
    fail('expected MissingToolsException');
  }

  test('nothing missing: require returns', () async {
    final pm = _Pm();
    await BuildTools(
      pm,
      LinuxPlatformInfo(),
      osReleasePath: p.join(temp.path, 'none'),
    ).require(['make'], devPackages: ['libxml-2.0']);
    expect(pm.specs.first.executable, 'sh');
    expect(pm.specs.first.arguments, ['-c', 'command -v "\$1"', 'sh', 'make']);
    expect(pm.specs.last.executable, 'pkg-config');
    expect(pm.specs.last.arguments, ['--exists', 'libxml-2.0']);
  });

  test('ubuntu: apt command without dev packages when headers exist', () async {
    final e = await missingFor('NAME="Ubuntu"\nID=ubuntu\nID_LIKE=debian\n');
    expect(e.missing, ['re2c']);
    expect(
      e.installCommand,
      'sudo apt install build-essential autoconf bison re2c pkg-config\n'
      'Then run the same pvm command again.',
    );
  });

  test('a missing dev module adds the full -dev list', () async {
    final e = await missingFor(
      'ID=debian\n',
      missing: {'icu-uc'},
      devPackages: ['libxml-2.0', 'icu-uc'],
    );
    expect(e.missing, ['icu-uc']);
    expect(
      e.installCommand,
      startsWith(
        'sudo apt install build-essential autoconf bison re2c pkg-config '
        'libxml2-dev libsqlite3-dev libssl-dev',
      ),
    );
    expect(e.installCommand, contains('libxslt1-dev\n'));
  });

  test('no pkg-config: dev modules count as missing', () async {
    final e = await missingFor(
      'ID=ubuntu\n',
      missing: {'pkg-config'},
      devPackages: ['libxml-2.0'],
    );
    expect(e.missing, contains('libxml-2.0'));
    expect(e.installCommand, contains('libxml2-dev'));
  });

  test('ID_LIKE picks the family of a derivative', () async {
    final e = await missingFor('ID=linuxmint\nID_LIKE="ubuntu debian"\n');
    expect(e.installCommand, startsWith('sudo apt install build-essential'));
  });

  for (final (osRelease, prefix) in [
    ('ID=fedora\n', 'sudo dnf install gcc make autoconf bison re2c pkgconf'),
    (
      'ID="rocky"\nID_LIKE="rhel centos fedora"\n',
      'sudo dnf install gcc make autoconf bison re2c pkgconf',
    ),
    ('ID=arch\n', 'sudo pacman -S base-devel'),
    ('ID=alpine\n', 'sudo apk add build-base autoconf'),
  ]) {
    test('$osRelease -> $prefix', () async {
      final e = await missingFor(osRelease, devPackages: ['zlib']);
      expect(e.installCommand, startsWith(prefix));
      expect(
        e.installCommand,
        endsWith('Then run the same pvm command again.'),
      );
    });
  }

  test('macOS: xcode-select, then brew', () async {
    final e = await missingFor(null, platform: MacOSPlatformInfo());
    expect(
      e.installCommand,
      startsWith(
        'xcode-select --install\n'
        'brew install autoconf bison re2c pkg-config',
      ),
    );
    expect(e.installCommand, endsWith('Then run the same pvm command again.'));
  });

  test('macOS: brew prefixes of keg-only formulae go into PKG_CONFIG_PATH '
      'ahead of the existing value', () async {
    final pm = _Pm(const {}, {
      'openssl@3': '/opt/homebrew/opt/openssl@3',
      'icu4c': '/opt/homebrew/opt/icu4c',
    });
    final tools = BuildTools(
      pm,
      MacOSPlatformInfo(),
      environment: const {'PKG_CONFIG_PATH': '/mine'},
    );
    await tools.require(['make'], devPackages: ['openssl']);

    final pkgConfig = pm.specs.lastWhere((s) => s.executable == 'pkg-config');
    expect(pkgConfig.environment, {
      'PKG_CONFIG_PATH':
          '/opt/homebrew/opt/openssl@3/lib/pkgconfig:'
          '/opt/homebrew/opt/icu4c/lib/pkgconfig:/mine',
    });
    expect(
      pm.specs.where((s) => s.executable == 'brew').map((s) => s.arguments),
      [
        ['--prefix', 'openssl@3'],
        ['--prefix', 'icu4c'],
        ['--prefix', 'libxml2'],
        ['--prefix', 'libpq'],
      ],
    );
  });

  test('macOS without brew: no extra environment', () async {
    final tools = BuildTools(_Pm(), MacOSPlatformInfo(), environment: const {});
    expect(await tools.buildEnvironment(), isNull);
  });

  test('Linux never asks brew', () async {
    final pm = _Pm();
    final tools = BuildTools(pm, LinuxPlatformInfo(), environment: const {});
    expect(await tools.buildEnvironment(), isNull);
    expect(pm.specs, isEmpty);
  });

  test('unknown distro lists the missing names only', () async {
    final e = await missingFor('ID=gentoo\n');
    expect(
      e.installCommand,
      'Install with your system package manager: re2c\n'
      'Then run the same pvm command again.',
    );
  });

  test('no os-release is an unknown distro', () async {
    final e = await missingFor(null);
    expect(e.installCommand, startsWith('Install with your system'));
  });
}
