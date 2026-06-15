import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/domain/exceptions.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/project.dart';

void main() {
  group('Project', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pvm_project_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<File> writePvmrcFile(String dirPath, String contents) async {
      final file = File(p.join(dirPath, PvmConstants.pvmrcFileName));
      await file.writeAsString(contents);
      return file;
    }

    group('findFromPath', () {
      test('returns project at start path when .pvmrc is present', () async {
        await writePvmrcFile(tempDir.path, '8.2');

        final project = await Project.findFromPath(tempDir.path);

        expect(project.rootDirectory.path, equals(tempDir.path));
      });

      test('walks up to parent when .pvmrc is in ancestor', () async {
        await writePvmrcFile(tempDir.path, '8.2');
        final nested = Directory(p.join(tempDir.path, 'a', 'b', 'c'));
        await nested.create(recursive: true);

        final project = await Project.findFromPath(nested.path);

        expect(project.rootDirectory.path, equals(tempDir.path));
      });

      test(
        'skips user-profile .pvm when walking up from nested path',
        () async {
          final nested = Directory(p.join(tempDir.path, 'src'));
          await nested.create(recursive: true);

          final project = await Project.findFromPath(nested.path);

          expect(project.rootDirectory.path, equals(nested.path));
        },
      );

      test('returns project when .pvm marker exists without .pvmrc', () async {
        final pvmDir = Directory(p.join(tempDir.path, PvmConstants.pvmDirName));
        await pvmDir.create();
        final nested = Directory(p.join(tempDir.path, 'src'));
        await nested.create(recursive: true);

        final project = await Project.findFromPath(nested.path);

        expect(project.rootDirectory.path, equals(tempDir.path));
      });

      test('ignores .php-version when only legacy file present', () async {
        await File(p.join(tempDir.path, '.php-version')).writeAsString('8.2\n');
        final nested = Directory(p.join(tempDir.path, 'src'));
        await nested.create(recursive: true);

        final project = await Project.findFromPath(nested.path);

        expect(project.rootDirectory.path, equals(nested.path));
      });

      test('falls back to start path when no .pvmrc or .pvm exists', () async {
        final nested = Directory(p.join(tempDir.path, 'a', 'b'));
        await nested.create(recursive: true);

        final project = await Project.findFromPath(nested.path);

        expect(project.rootDirectory.path, equals(nested.path));
      });

      test('stops at filesystem root without throwing', () async {
        final nested = Directory(p.join(tempDir.path, 'a'));
        await nested.create(recursive: true);

        final project = await Project.findFromPath(nested.path);

        expect(project, isA<Project>());
        expect(project.rootDirectory.path, equals(nested.path));
      });
    });

    group('getConfiguredVersion', () {
      test('returns null when .pvmrc file does not exist', () async {
        final project = Project(tempDir);

        final version = await project.getConfiguredVersion();

        expect(version, isNull);
      });

      test('returns null when file is empty', () async {
        await writePvmrcFile(tempDir.path, '');

        final project = Project(tempDir);
        final version = await project.getConfiguredVersion();

        expect(version, isNull);
      });

      test('returns null when file is whitespace only', () async {
        await writePvmrcFile(tempDir.path, '   \n\t  ');

        final project = Project(tempDir);
        final version = await project.getConfiguredVersion();

        expect(version, isNull);
      });

      test('reads plain text major.minor', () async {
        await writePvmrcFile(tempDir.path, '8.2');

        final project = Project(tempDir);
        final version = await project.getConfiguredVersion();

        expect(version, isNotNull);
        expect(version.toString(), equals('8.2'));
      });

      test('reads plain text major.minor.patch', () async {
        await writePvmrcFile(tempDir.path, '8.2.10');

        final project = Project(tempDir);
        final version = await project.getConfiguredVersion();

        expect(version.toString(), equals('8.2.10'));
      });

      test('strips trailing whitespace and newlines from plain text', () async {
        await writePvmrcFile(tempDir.path, '  8.2.10\n');

        final project = Project(tempDir);
        final version = await project.getConfiguredVersion();

        expect(version.toString(), equals('8.2.10'));
      });

      test('reads JSON object with version field', () async {
        await writePvmrcFile(tempDir.path, '{"version": "8.3.0"}');

        final project = Project(tempDir);
        final version = await project.getConfiguredVersion();

        expect(version.toString(), equals('8.3.0'));
      });

      test('reads pretty-printed JSON object', () async {
        await writePvmrcFile(tempDir.path, '''
{
  "version": "8.1.5"
}''');

        final project = Project(tempDir);
        final version = await project.getConfiguredVersion();

        expect(version.toString(), equals('8.1.5'));
      });

      test('throws on invalid version format in plain text', () async {
        await writePvmrcFile(tempDir.path, 'not-a-version');

        final project = Project(tempDir);

        expect(
          () => project.getConfiguredVersion(),
          throwsA(isA<InvalidVersionFormatException>()),
        );
      });
    });

    group('setConfiguredVersion', () {
      test(
        'writes JSON file with version key readable by getConfiguredVersion',
        () async {
          final project = Project(tempDir);
          await project.setConfiguredVersion(PhpVersion.parse('8.2'));

          final raw = await project.pvmrcFile.readAsString();
          expect(raw, contains('"version"'));
          expect(raw, contains('"8.2"'));

          final reread = await project.getConfiguredVersion();
          expect(reread.toString(), equals('8.2'));
        },
      );
    });

    group('hasActiveVersion', () {
      test('returns false when .pvm directory missing', () async {
        final project = Project(tempDir);
        expect(await project.hasActiveVersion(), isFalse);
      });

      test('returns true when .pvm directory exists', () async {
        final pvmDir = Directory(p.join(tempDir.path, PvmConstants.pvmDirName));
        await pvmDir.create();

        final project = Project(tempDir);
        expect(await project.hasActiveVersion(), isTrue);
      });
    });

    group('paths', () {
      test('pvmrcFile is rooted under project directory', () {
        final project = Project(tempDir);
        expect(
          project.pvmrcFile.path,
          equals(p.join(tempDir.path, PvmConstants.pvmrcFileName)),
        );
      });

      test('pvmDirectory is rooted under project directory', () {
        final project = Project(tempDir);
        expect(
          project.pvmDirectory.path,
          equals(p.join(tempDir.path, PvmConstants.pvmDirName)),
        );
      });
    });
  });
}
