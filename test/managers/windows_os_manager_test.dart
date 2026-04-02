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
  });
}
