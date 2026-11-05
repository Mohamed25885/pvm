@TestOn('windows')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pvm/src/core/symlink_inspector.dart';
import 'package:test/test.dart';

import '../mocks/mock_os_manager.dart';

/// The 8.3 short form of [path], or `null` when the volume has none.
Future<String?> _shortName(String path) async {
  final result = await Process.run(
    'powershell',
    [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'(New-Object -ComObject Scripting.FileSystemObject).GetFolder($env:PVM_P).ShortPath',
    ],
    environment: {'PVM_P': path},
  );
  final short = '${result.stdout}'.trim();
  if (result.exitCode != 0 || short.isEmpty || p.equals(short, path)) {
    return null;
  }
  return short;
}

void main() {
  test('a junction target spelt long is inside a short-name versions root '
      '(not orphaned)', () async {
    final temp = await Directory.systemTemp.createTemp('pvm long name root ');
    try {
      await Directory(
        p.join(temp.path, 'versions', '8.3.14'),
      ).create(recursive: true);
      final longRoot = await Directory(
        p.join(temp.path, 'versions'),
      ).resolveSymbolicLinks();
      final target = p.join(longRoot, '8.3.14');
      final shortRoot = await _shortName(temp.path);
      if (shortRoot == null) {
        markTestSkipped('8.3 short names are disabled on this volume');
        return;
      }

      const link = r'C:\Users\sam\.pvm';
      final os = MockOSManager()
        ..symlinkTargets[link] = target
        ..setDirectoryExistsResult(target, true);

      final info = await SymLinkInspector(
        os,
      ).inspect(linkPath: link, versionsRoot: p.join(shortRoot, 'versions'));

      expect(info.status, SymLinkStatus.ok);
      expect(info.version.toString(), '8.3.14');
    } finally {
      await temp.delete(recursive: true);
    }
  });
}
