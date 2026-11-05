import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pvm/src/core/link_manager.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/domain/exceptions.dart';
import 'package:pvm/src/managers/io_os_manager.dart';
import 'package:test/test.dart';

/// Records calls instead of touching the filesystem.
class _RecordingLinks implements ILinkManager {
  final created = <(String, String)>[];

  @override
  Future<void> createDirLink(String link, String target) async =>
      created.add((link, target));

  @override
  Future<bool> isLink(String path) async => false;

  @override
  Future<String?> readTarget(String path) async => null;

  @override
  Future<void> remove(String path) async {}
}

void main() {
  group('createLinkManager (2.3)', () {
    test('Windows uses junctions, Unix uses symlinks', () {
      expect(
        createLinkManager(WindowsPlatformInfo()),
        isA<JunctionLinkManager>(),
      );
      expect(
        createLinkManager(LinuxPlatformInfo()),
        isNot(isA<JunctionLinkManager>()),
      );
      expect(createLinkManager(MacOSPlatformInfo()), isA<SymlinkLinkManager>());
    });
  });

  group('IoOSManager (2.4)', () {
    IoOSManager manager(
      PlatformInfo platform,
      Map<String, String> env, [
      ILinkManager? links,
    ]) => IoOSManager(
      platformInfo: platform,
      linkManager: links ?? _RecordingLinks(),
      environment: env,
    );

    test('home comes from the platform key first', () {
      final env = {'HOME': '/home/u', 'USERPROFILE': r'C:\Users\u'};
      expect(manager(LinuxPlatformInfo(), env).getHomeDirectory(), '/home/u');
      expect(
        manager(WindowsPlatformInfo(), env).getHomeDirectory(),
        r'C:\Users\u',
      );
    });

    test('home falls back to the other key, then throws', () {
      expect(
        manager(WindowsPlatformInfo(), {'HOME': '/h'}).getHomeDirectory(),
        '/h',
      );
      expect(
        () => manager(LinuxPlatformInfo(), {'HOME': ' '}).getHomeDirectory(),
        throwsException,
      );
    });

    test('PVM_HOME and PVM_VERSIONS_HOME are honoured on every OS', () {
      for (final platform in [WindowsPlatformInfo(), LinuxPlatformInfo()]) {
        final m = manager(platform, {
          'PVM_HOME': p.join('a', 'pvm'),
          'PVM_VERSIONS_HOME': p.join('b', 'versions'),
        });
        expect(m.programDirectory, p.join('a', 'pvm'));
        expect(m.phpVersionsPath, p.join('b', 'versions'));
      }
    });

    group('with a temp dir', () {
      late Directory temp;

      setUp(() async {
        temp = await Directory.systemTemp.createTemp('pvm_io_os_');
      });

      tearDown(() async {
        await temp.delete(recursive: true);
      });

      test('getAvailableVersions lists bare directory names only', () async {
        await Directory(p.join(temp.path, '8.3.14')).create();
        await Directory(p.join(temp.path, 'tmp')).create();
        await File(p.join(temp.path, 'notes.txt')).writeAsString('x');

        final names = manager(
          LinuxPlatformInfo(),
          {},
        ).getAvailableVersions(temp.path);

        expect(names, unorderedEquals(['8.3.14', 'tmp']));
      });

      test(
        'createSymLink validates, then delegates to the link manager',
        () async {
          final target = await Directory(p.join(temp.path, '8.3.14')).create();
          final link = p.join(temp.path, '.pvm');
          final links = _RecordingLinks();

          await manager(
            LinuxPlatformInfo(),
            {},
            links,
          ).createSymLink('8.3.14', target.path, link);

          expect(links.created, [(link, target.path)]);
        },
      );

      test('createSymLink rejects a missing source on every OS', () async {
        final links = _RecordingLinks();
        await expectLater(
          manager(LinuxPlatformInfo(), {}, links).createSymLink(
            '8.3',
            p.join(temp.path, 'missing'),
            p.join(temp.path, '.pvm'),
          ),
          throwsA(
            predicate((e) => '$e'.contains('Source directory does not exist')),
          ),
        );
        expect(links.created, isEmpty);
      });

      test('createSymLink never replaces a real directory (S2)', () async {
        final target = await Directory(p.join(temp.path, '8.3.14')).create();
        final slot = await Directory(p.join(temp.path, '.pvm')).create();
        await File(p.join(slot.path, 'keep.txt')).writeAsString('data');
        final links = _RecordingLinks();

        await expectLater(
          manager(
            LinuxPlatformInfo(),
            {},
            links,
          ).createSymLink('8.3.14', target.path, slot.path),
          throwsA(isA<LinkSlotOccupiedException>()),
        );
        expect(links.created, isEmpty);
        expect(await File(p.join(slot.path, 'keep.txt')).exists(), isTrue);
      });
    });
  });
}
