import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/domain/exceptions/probe_exception.dart';
import 'package:pvm/src/services/folder_probe.dart';
import 'package:test/test.dart';

import 'fake_process_manager.dart';

CapturedProcessResult _ok(String out) =>
    CapturedProcessResult(stdout: out, stderr: '', exitCode: 0);

String _json(String build, String ext) => jsonEncode({
  'v': '8.4.27',
  'zts': false,
  'arch': 'x86_64',
  'ext': ext,
  'build': build,
});

/// Fails the way IoProcessManager does when the binary cannot be started.
class _UnstartablePm extends FakeProcessManager {
  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async =>
      throw Exception('Failed to start process "${spec.executable}"');
}

void main() {
  late Directory tmp;
  late FakeProcessManager pm;
  late String ext;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pvm_probe_');
    pm = FakeProcessManager();
    ext = p.join(tmp.path, 'ext');
    Directory(ext).createSync(recursive: true);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String touch(String rel) {
    final f = File(p.joinAll([tmp.path, ...rel.split('/')]))
      ..createSync(recursive: true);
    return f.path;
  }

  test('unix: parses build line and finds php-config<X.Y>', () async {
    final php = touch('bin/php');
    final cfg = touch('bin/php-config8.4');
    pm.capturedResults[php] = _ok(_json('API20240924,NTS', ext));
    pm.capturedResults[cfg] = _ok('/opt/php\n');

    final r = await FolderProbe(pm, LinuxPlatformInfo()).probe(tmp.path);

    expect(r.version, '8.4.27');
    expect(r.zts, isFalse);
    expect(r.apiNo, '20240924');
    expect(r.arch, 'x64');
    expect(r.phpConfig, cfg);
    expect(r.prefix, '/opt/php');
    expect(r.extensionDir, ext);
    expect(r.writable, isTrue);
    expect(r.vsVersion, isNull);
    expect(pm.capturedSpecs.first.arguments.first, '-n');
  });

  test('windows: reads VS version, no php-config', () async {
    final php = touch('php.exe');
    pm.capturedResults[php] = _ok(_json('API20240924,NTS,VS17', ext));

    final r = await FolderProbe(pm, WindowsPlatformInfo()).probe(tmp.path);

    expect(r.vsVersion, 'VS17');
    expect(r.apiNo, '20240924');
    expect(r.phpConfig, isNull);
    expect(r.prefix, isNull);
  });

  test('zts build is detected', () async {
    final php = touch('bin/php');
    pm.capturedResults[php] = _ok(
      jsonEncode({
        'v': '8.4.27',
        'zts': true,
        'arch': 'x86_64',
        'ext': ext,
        'build': 'API20240924,TS',
      }),
    );
    final r = await FolderProbe(pm, LinuxPlatformInfo()).probe(tmp.path);
    expect(r.zts, isTrue);
  });

  test('writable false when extensionDir is missing', () async {
    final php = touch('bin/php');
    pm.capturedResults[php] = _ok(
      _json('API20240924,NTS', p.join(tmp.path, 'nope')),
    );
    final r = await FolderProbe(pm, LinuxPlatformInfo()).probe(tmp.path);
    expect(r.writable, isFalse);
  });

  test('throws ProbeException when php is missing', () {
    expect(
      FolderProbe(pm, LinuxPlatformInfo()).probe(tmp.path),
      throwsA(isA<ProbeException>()),
    );
  });

  test('throws ProbeException when php cannot be started (R12)', () {
    touch('bin/php');
    expect(
      FolderProbe(_UnstartablePm(), LinuxPlatformInfo()).probe(tmp.path),
      throwsA(isA<ProbeException>()),
    );
  });

  test('throws ProbeException on non-zero exit', () {
    final php = touch('bin/php');
    pm.capturedResults[php] = const CapturedProcessResult(
      stdout: '',
      stderr: 'boom',
      exitCode: 1,
    );
    expect(
      FolderProbe(pm, LinuxPlatformInfo()).probe(tmp.path),
      throwsA(isA<ProbeException>()),
    );
  });

  test('throws ProbeException on unparsable output', () {
    final php = touch('bin/php');
    pm.capturedResults[php] = _ok('not json');
    expect(
      FolderProbe(pm, LinuxPlatformInfo()).probe(tmp.path),
      throwsA(isA<ProbeException>()),
    );
  });

  test('wrong-shaped JSON throws ProbeException', () {
    final php = touch('bin/php');
    pm.capturedResults[php] = _ok('{"v":1}');
    expect(
      FolderProbe(pm, LinuxPlatformInfo()).probe(tmp.path),
      throwsA(isA<ProbeException>()),
    );
  });

  test('plain php-config wins over php-config<X.Y>', () async {
    final php = touch('bin/php');
    final cfg = touch('bin/php-config');
    final cfg2 = touch('bin/php-config8.4');
    pm.capturedResults[php] = _ok(_json('API20240924,NTS', ext));
    pm.capturedResults[cfg] = _ok('/a\n');
    pm.capturedResults[cfg2] = _ok('/b\n');
    final r = await FolderProbe(pm, LinuxPlatformInfo()).probe(tmp.path);
    expect(r.phpConfig, cfg);
    expect(r.prefix, '/a');
  });

  test('arch is normalized', () async {
    final php = touch('bin/php');
    for (final (raw, want) in [
      ('AMD64', 'x64'),
      ('x86_64', 'x64'),
      ('aarch64', 'arm64'),
      ('i686', 'x86'),
    ]) {
      pm.capturedResults[php] = _ok(
        jsonEncode({
          'v': '8.4.27',
          'zts': false,
          'arch': raw,
          'ext': ext,
          'build': 'API20240924,NTS',
        }),
      );
      final r = await FolderProbe(pm, LinuxPlatformInfo()).probe(tmp.path);
      expect(r.arch, want, reason: raw);
    }
  });

  test(
    'windows: extensionDir is <folder>/ext, not the compiled default',
    () async {
      final php = touch('php.exe');
      pm.capturedResults[php] = _ok(
        _json('API20240924,TS,VS17', r'C:\php\ext'),
      );
      final r = await FolderProbe(pm, WindowsPlatformInfo()).probe(tmp.path);
      expect(r.extensionDir, p.join(tmp.path, 'ext'));
    },
  );

  test(
    'writable false when extensionDir is read-only',
    () async {
      final php = touch('bin/php');
      pm.capturedResults[php] = _ok(_json('API20240924,NTS', ext));
      await Process.run('chmod', ['555', ext]);
      addTearDown(() => Process.run('chmod', ['755', ext]));
      final r = await FolderProbe(pm, LinuxPlatformInfo()).probe(tmp.path);
      expect(r.writable, isFalse);
    },
    skip: Platform.isWindows ? 'chmod not applicable on Windows' : false,
  );
}
