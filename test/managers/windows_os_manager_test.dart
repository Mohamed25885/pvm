@TestOn('windows')
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:pvm/src/managers/windows_os_manager.dart';

void main() {
  group('WindowsOSManager', () {
    late WindowsOSManager manager;

    setUp(() {
      manager = WindowsOSManager();
    });

    test('getHomeDirectory returns valid path', () async {
      final home = manager.getHomeDirectory();
      expect(home, isNotEmpty);
      expect(await Directory(home).exists(), isTrue);
    });

    test('getAvailableVersions returns empty when versionsPath does not exist',
        () {
      final versions =
          manager.getAvailableVersions('C:\\nonexistent\\versions');
      expect(versions, isEmpty);
    });

    test('getAvailableVersions returns bare basenames (no separators)',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('pvm_versions_');
      try {
        await Directory(p.join(tempDir.path, '8.2.10')).create();
        await Directory(p.join(tempDir.path, '8.3.0')).create();
        await File(p.join(tempDir.path, 'not-a-dir.txt')).writeAsString('x');

        final versions = manager.getAvailableVersions(tempDir.path);

        expect(versions, containsAll(['8.2.10', '8.3.0']));
        expect(versions, hasLength(2));
        for (final v in versions) {
          expect(v.contains(r'\'), isFalse,
              reason: 'must be bare basename without separators');
          expect(v.contains('/'), isFalse,
              reason: 'must be bare basename without separators');
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('directoryExists returns true for existing directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('pvm_test_');
      expect(await manager.directoryExists(tempDir.path), isTrue);
      await tempDir.delete(recursive: true);
    });

    test('directoryExists returns false for non-existent directory', () async {
      expect(await manager.directoryExists('C:\\nonexistent\\dir'), isFalse);
    });

    test('fileExists returns true for existing file', () async {
      final tempFile = File('${Directory.systemTemp.path}\\pvm_test_file.txt');
      await tempFile.writeAsString('test');
      expect(await manager.fileExists(tempFile.path), isTrue);
      await tempFile.delete();
    });

    test('fileExists returns false for non-existent file', () async {
      expect(await manager.fileExists('C:\\nonexistent\\file.txt'), isFalse);
    });

    test('createSymLink throws when source is empty', () async {
      final tempHome = await Directory.systemTemp.createTemp('pvm_home_');
      final to = p.join(tempHome.path, '.pvm');
      try {
        await expectLater(
          manager.createSymLink('8.0', '', to),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('Source directory does not exist'))),
        );
      } finally {
        await tempHome.delete(recursive: true);
      }
    });

    test('createSymLink throws when source does not exist', () async {
      final tempHome = await Directory.systemTemp.createTemp('pvm_home_');
      final to = p.join(tempHome.path, '.pvm');
      try {
        await expectLater(
          manager.createSymLink('8.0', 'C:\\nonexistent\\source', to),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('Source directory does not exist'))),
        );
      } finally {
        await tempHome.delete(recursive: true);
      }
    });

    group('isSymLink', () {
      test('returns false for non-existent path', () async {
        expect(await manager.isSymLink(r'C:\nonexistent\foo'), isFalse);
      });

      test('returns false for a regular directory', () async {
        final tempDir = await Directory.systemTemp.createTemp('pvm_islink_');
        try {
          expect(await manager.isSymLink(tempDir.path), isFalse);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('returns true for a symbolic link', () async {
        final tempDir = await Directory.systemTemp.createTemp('pvm_islink_');
        try {
          final source = Directory(p.join(tempDir.path, 'src'));
          await source.create();
          final link = p.join(tempDir.path, 'lnk');
          try {
            await Link(link).create(source.path);
            expect(await manager.isSymLink(link), isTrue);
          } on FileSystemException catch (_) {
            // Symlink creation requires Developer Mode or admin on Windows.
            // Treat as test-skipped.
            return;
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('readSymLinkTarget', () {
      test('returns null for non-existent path', () async {
        final result = await manager.readSymLinkTarget(r'C:\nonexistent\foo');
        expect(result, isNull);
      });

      test('returns null for a regular directory', () async {
        final tempDir = await Directory.systemTemp.createTemp('pvm_readlink_');
        try {
          final result = await manager.readSymLinkTarget(tempDir.path);
          expect(result, isNull);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test('returns the link target for a symlink', () async {
        final tempDir = await Directory.systemTemp.createTemp('pvm_readlink_');
        try {
          final source = Directory(p.join(tempDir.path, 'src'));
          await source.create();
          final link = p.join(tempDir.path, 'lnk');
          try {
            await Link(link).create(source.path);
          } on FileSystemException catch (_) {
            return; // skipped due to Dev Mode/admin
          }

          final target = await manager.readSymLinkTarget(link);
          expect(target, equals(source.path));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('deleteSymLink', () {
      test('no-op when path does not exist', () async {
        await manager.deleteSymLink(r'C:\nonexistent\never');
      });

      test('removes an existing symlink without touching the target', () async {
        final tempDir = await Directory.systemTemp.createTemp('pvm_dellink_');
        try {
          final source = Directory(p.join(tempDir.path, 'src'));
          await source.create();
          final link = p.join(tempDir.path, 'lnk');
          try {
            await Link(link).create(source.path);
          } on FileSystemException catch (_) {
            return;
          }

          await manager.deleteSymLink(link);

          final stillThere =
              await FileSystemEntity.type(link, followLinks: false);
          expect(stillThere, equals(FileSystemEntityType.notFound));
          expect(await source.exists(), isTrue,
              reason: 'deleting a symlink must not delete the target');
        } finally {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        }
      });
    });

    group('deleteDirectory', () {
      test('no-op when path does not exist', () async {
        await manager.deleteDirectory(r'C:\nonexistent\never');
      });

      test('recursively deletes a directory tree', () async {
        final tempDir = await Directory.systemTemp.createTemp('pvm_deldir_');
        final nested = Directory(p.join(tempDir.path, 'a', 'b'));
        await nested.create(recursive: true);
        await File(p.join(nested.path, 'leaf.txt')).writeAsString('hello');

        await manager.deleteDirectory(tempDir.path);

        expect(await tempDir.exists(), isFalse);
      });
    });
  });
}
