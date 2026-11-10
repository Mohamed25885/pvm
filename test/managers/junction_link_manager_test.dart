@TestOn('windows')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/link_manager.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/managers/io_os_manager.dart';

IoOSManager _manager([ILinkManager links = const JunctionLinkManager()]) =>
    IoOSManager(platformInfo: WindowsPlatformInfo(), linkManager: links);

/// Junctions store the long, resolved path; the temp dir may be an 8.3
/// short name on CI (`C:\Users\RUNNER~1`), so compare canonical forms.
Future<bool> _sameDir(String a, String b) async => p.equals(
  await Directory(a).resolveSymbolicLinks(),
  await Directory(b).resolveSymbolicLinks(),
);

void main() {
  group('JunctionLinkManager via IoOSManager (1.1)', () {
    late Directory temp;
    late String target;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('pvm_junction_');
      // Characters that break naive shell quoting must be harmless.
      target = p.join(temp.path, 'versions & %PATH% x', '8.3.14');
      await File(p.join(target, 'php.exe')).create(recursive: true);
    });

    tearDown(() async {
      final link = p.join(temp.path, 'project', '.pvm');
      if (await FileSystemEntity.isLink(link)) await Link(link).delete();
      await temp.delete(recursive: true);
    });

    test('creates a junction by default (no privilege needed)', () async {
      final project = await Directory(p.join(temp.path, 'project')).create();
      final link = p.join(project.path, '.pvm');

      await _manager().createSymLink('8.3.14', target, link);

      expect(await FileSystemEntity.isLink(link), isTrue);
      expect(await _sameDir(await Link(link).target(), target), isTrue);
      expect(await File(p.join(link, 'php.exe')).exists(), isTrue);
      // Junctions resolve as directories even without Developer Mode.
      final linkStat = await Process.run('cmd', [
        '/c',
        'dir',
        '/AL',
        project.path,
      ]);
      expect('${linkStat.stdout}', contains('<JUNCTION>'));
    });

    test('replaces an existing junction (switching versions)', () async {
      final other = p.join(temp.path, 'versions & %PATH% x', '8.2.0');
      await File(p.join(other, 'php.exe')).create(recursive: true);
      final project = await Directory(p.join(temp.path, 'project')).create();
      final link = p.join(project.path, '.pvm');
      final manager = _manager();

      await manager.createSymLink('8.3.14', target, link);
      await manager.createSymLink('8.2.0', other, link);

      expect(await _sameDir(await Link(link).target(), other), isTrue);
      expect(await File(p.join(target, 'php.exe')).exists(), isTrue);
    });

    test('falls back to a symlink when a junction cannot be made', () async {
      final project = await Directory(p.join(temp.path, 'project')).create();
      final link = p.join(project.path, '.pvm');
      final manager = _manager(
        JunctionLinkManager(
          createJunction: (_, _) async => throw Exception('not on NTFS'),
        ),
      );

      try {
        await manager.createSymLink('8.3.14', target, link);
      } on Exception catch (e) {
        // Without Developer Mode the symlink fallback is refused; the error
        // must mention both attempts.
        expect('$e', contains('junction attempt'));
        return;
      }
      expect(await FileSystemEntity.isLink(link), isTrue);
    });
  });
}
