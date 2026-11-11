import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/version_registry.dart';
import 'package:pvm/src/services/build_tools.dart';
import 'package:pvm/src/services/extensions/pecl_source_builder.dart';
import 'package:test/test.dart';

import '../../mocks/mock_console.dart';

final _tgz = utf8.encode('fake xdebug tgz');
final _sha = crypto.sha256.convert(_tgz).toString();

/// Plays sh/tar/php-config/php and the build steps.
class _Pm implements IProcessManager {
  final String slot;
  final interactive = <ProcessSpec>[];
  final captured = <ProcessSpec>[];
  String? prefix; // php-config --prefix output; defaults to [slot]
  Set<String> missingTools = {};
  _Pm(this.slot);

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    interactive.add(spec);
    if (spec.executable == 'make') {
      final ext = p.basename(spec.workingDirectory!).split('-').first;
      File(p.join(spec.workingDirectory!, 'modules', '$ext.so'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2]);
    }
    return 0;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    captured.add(spec);
    var out = '';
    var code = 0;
    final exe = spec.executable;
    if (exe == 'sh') {
      code = missingTools.contains(spec.arguments.last) ? 1 : 0;
    } else if (exe == 'tar') {
      final dest = spec.arguments[spec.arguments.indexOf('-C') + 1];
      final tgz = p.basenameWithoutExtension(spec.arguments[1]);
      Directory(p.join(dest, tgz)).createSync(recursive: true);
    } else if (p.basename(exe).startsWith('php-config')) {
      out = '${prefix ?? slot}\n';
    } else if (exe.endsWith('php')) {
      out = '[Zend Modules]\nXdebug\ngrpc\n';
    }
    return CapturedProcessResult(stdout: out, stderr: '', exitCode: code);
  }

  @override
  Future<String> resolveSystemCommand(String command) async => command;
}

void main() {
  late Directory temp;
  late String slotDir;
  late _Pm pm;
  late MockConsole console;
  late List<Uri> requested;
  late String stable;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pvm_pecl_');
    slotDir = p.join(temp.path, 'versions', '8.4');
    pm = _Pm(slotDir);
    console = MockConsole();
    requested = [];
    stable = '3.5.3\n';
    for (final n in ['php', 'php-config', 'phpize']) {
      File(p.join(slotDir, 'bin', n)).createSync(recursive: true);
    }
  });
  tearDown(() async => temp.delete(recursive: true));

  InstalledSlot slot({String? phpConfig = ''}) => InstalledSlot(
    PhpVersion.parse('8.4.27'),
    slotDir,
    InstallRecord(
      version: '8.4.27',
      sourceUrl: '',
      archiveSha256: '',
      verified: true,
      installedAt: DateTime.utc(2026),
      files: const {},
      kind: SlotKind.source,
      phpConfig: phpConfig == ''
          ? p.join(slotDir, 'bin', 'php-config')
          : phpConfig,
      prefix: slotDir,
      extensionDir: p.join(slotDir, 'lib', 'ext'),
    ),
  );

  PeclSourceBuilder builder() {
    final os = LinuxPlatformInfo();
    return PeclSourceBuilder(
      platform: os,
      console: console,
      processManager: pm,
      buildTools: BuildTools(
        pm,
        os,
        osReleasePath: p.join(temp.path, 'none'),
        environment: const {},
      ),
      jobs: 3,
      client: MockClient((r) async {
        requested.add(r.url);
        if (r.url.path.endsWith('stable.txt')) {
          return http.Response(stable, 200);
        }
        return http.Response.bytes(_tgz, 200);
      }),
      retryDelay: Duration.zero,
    );
  }

  List<String> checkedTools() => [
    for (final s in pm.captured)
      if (s.executable == 'sh') s.arguments.last,
  ];

  test('fetches stable + tgz, builds with the slot phpize and php-config, '
      'commits the .so and returns an unverified entry', () async {
    final entry = await builder().install('xdebug', slot());

    expect(requested.map((u) => u.toString()), [
      'https://pecl.php.net/rest/r/xdebug/stable.txt',
      'https://pecl.php.net/get/xdebug-3.5.3.tgz',
    ]);
    expect(checkedTools(), ['cc', 'make', 'autoconf', 'pkg-config']);

    final tar = pm.captured.firstWhere((s) => s.executable == 'tar');
    expect(tar.arguments.first, '-xzf');
    final src = p.join(tar.arguments[3], 'xdebug-3.5.3');
    final phpConfig = p.join(slotDir, 'bin', 'php-config');
    expect(pm.interactive.map((s) => [s.executable, ...s.arguments]).toList(), [
      [p.join(slotDir, 'bin', 'phpize')],
      [p.join(src, 'configure'), '--with-php-config=$phpConfig'],
      ['make', '-j3'],
    ]);
    expect(pm.interactive.every((s) => s.workingDirectory == src), isTrue);

    final installed = File(p.join(slotDir, 'lib', 'ext', 'xdebug.so'));
    expect(installed.readAsBytesSync(), [1, 2]);
    expect(entry.name, 'xdebug');
    expect(entry.version, '3.5.3');
    expect(entry.file, 'xdebug.so');
    expect(entry.sha256, _sha);
    expect(entry.verified, isFalse);
    expect(Directory(tar.arguments[3]).existsSync(), isFalse);
  });

  test('uses phpize<X.Y> next to php-config<X.Y>', () async {
    for (final n in ['php-config', 'phpize']) {
      File(p.join(slotDir, 'bin', n)).deleteSync();
      File(p.join(slotDir, 'bin', '${n}8.4')).createSync();
    }
    await builder().install(
      'xdebug',
      slot(phpConfig: p.join(slotDir, 'bin', 'php-config8.4')),
    );
    expect(
      pm.interactive.first.executable,
      p.join(slotDir, 'bin', 'phpize8.4'),
    );
  });

  test('refuses a slot whose bin/php is gone', () async {
    File(p.join(slotDir, 'bin', 'php')).deleteSync();
    await expectLater(
      builder().install('xdebug', slot()),
      throwsA(
        isA<SlotBrokenException>().having(
          (e) => e.message,
          'message',
          'Slot 8.4 is broken (bin/php missing); reinstall it',
        ),
      ),
    );
    expect(requested, isEmpty);
  });

  test('a missing php-config or phpize is the broken-slot refusal', () async {
    for (final s in [slot(phpConfig: null), slot()]) {
      File(p.join(slotDir, 'bin', 'phpize')).deleteSync();
      await expectLater(
        builder().install('xdebug', s),
        throwsA(
          isA<SlotBrokenException>().having(
            (e) => e.message,
            'message',
            'Slot 8.4 is broken (bin/php missing); reinstall it',
          ),
        ),
      );
      File(p.join(slotDir, 'bin', 'phpize')).createSync();
    }
    expect(requested, isEmpty);
  });

  test('prefix guard refuses a slot built for another prefix', () async {
    pm.prefix = '/old/versions/8.4';
    await expectLater(
      builder().install('xdebug', slot()),
      throwsA(
        isA<SlotBrokenException>().having(
          (e) => e.message,
          'message',
          'Slot 8.4 was built for /old/versions/8.4; reinstall it with '
              'pvm install 8.4 --from-source --force',
        ),
      ),
    );
    expect(requested, isEmpty);
  });

  test('grpc also requires c++ and warns about the long build', () async {
    await builder().install('grpc', slot());
    expect(checkedTools(), ['cc', 'make', 'autoconf', 'pkg-config', 'c++']);
    expect(
      console.printed,
      contains('grpc is a long C++ build (can take 30+ minutes).'),
    );
  });

  test('a missing tool stops before any download', () async {
    pm.missingTools = {'autoconf'};
    await expectLater(
      builder().install('xdebug', slot()),
      throwsA(isA<MissingToolsException>()),
    );
    expect(requested, isEmpty);
  });

  test('rejects a malformed stable.txt version before any other URL', () async {
    stable = '../../etc\n';
    await expectLater(
      builder().install('xdebug', slot()),
      throwsA(isA<Exception>()),
    );
    expect(requested, hasLength(1));
  });
}
