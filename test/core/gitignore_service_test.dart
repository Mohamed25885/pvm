import 'dart:io';

import 'package:test/test.dart';

import '../../lib/src/core/gitignore_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pvm-gitignore-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ensureGitignoreIncludesPvm', () {
    test('returns true and creates .gitignore when it does not exist',
        () async {
      final service = GitIgnoreService();
      final result =
          await service.ensureGitignoreIncludesPvm(rootPath: tempDir.path);

      expect(result, isTrue);
      final gitignore = File('${tempDir.path}\\.gitignore');
      expect(await gitignore.exists(), isTrue);
      final content = await gitignore.readAsString();
      expect(content, contains('.pvm'));
    });

    test('returns true when adding .pvm entry to existing .gitignore',
        () async {
      final gitignore = File('${tempDir.path}\\.gitignore');
      await gitignore.writeAsString('build/\n');

      final service = GitIgnoreService();
      final result =
          await service.ensureGitignoreIncludesPvm(rootPath: tempDir.path);

      expect(result, isTrue);
      final content = await gitignore.readAsString();
      expect(content, contains('.pvm'));
      expect(content, contains('build/'));
    });

    test('returns false when .pvm already ignored (slash variant)', () async {
      final gitignore = File('${tempDir.path}\\.gitignore');
      await gitignore.writeAsString('/.pvm/\nbuild/\n');

      final service = GitIgnoreService();
      final result =
          await service.ensureGitignoreIncludesPvm(rootPath: tempDir.path);

      expect(result, isFalse);
      final content = await gitignore.readAsString();
      final matches = RegExp(r'/?\.pvm/?').allMatches(content).length;
      expect(matches, lessThanOrEqualTo(1));
    });

    test('returns false when .pvm already ignored (no-slash variant)',
        () async {
      final gitignore = File('${tempDir.path}\\.gitignore');
      await gitignore.writeAsString('.pvm\n');

      final service = GitIgnoreService();
      final result =
          await service.ensureGitignoreIncludesPvm(rootPath: tempDir.path);

      expect(result, isFalse);
      final content = await gitignore.readAsString();
      final pvmLines =
          content.split('\n').where((l) => l.contains('.pvm')).toList();
      expect(pvmLines.length, equals(1));
    });
  });

  group('ensurePvmSymlinkExists', () {
    test('returns true and creates symlink when target dir exists', () async {
      final versionsDir = Directory('${tempDir.path}\\versions');
      await versionsDir.create();

      final service = GitIgnoreService();
      final result = await service.ensurePvmSymlinkExists(
        symlinkPath: '${tempDir.path}\\.pvm',
        targetPath: '${tempDir.path}\\versions',
      );

      expect(result, isTrue);
      final link = Link('${tempDir.path}\\.pvm');
      expect(await link.exists(), isTrue);
    });

    test('returns false when target dir does not exist', () async {
      final service = GitIgnoreService();
      final result = await service.ensurePvmSymlinkExists(
        symlinkPath: '${tempDir.path}\\.pvm',
        targetPath: '${tempDir.path}\\versions',
      );

      expect(result, isFalse);
      final link = Link('${tempDir.path}\\.pvm');
      expect(await link.exists(), isFalse);
    });

    test('returns true when .pvm already exists', () async {
      final versionsDir = Directory('${tempDir.path}\\versions');
      await versionsDir.create();
      final existingFile = File('${tempDir.path}\\.pvm');
      await existingFile.create();

      final service = GitIgnoreService();
      final result = await service.ensurePvmSymlinkExists(
        symlinkPath: '${tempDir.path}\\.pvm',
        targetPath: '${tempDir.path}\\versions',
      );

      // Existing file is replaced with symlink — returns true
      expect(result, isTrue);
      final link = Link('${tempDir.path}\\.pvm');
      final file = File('${tempDir.path}\\.pvm');
      expect(await link.exists(), isTrue);
      expect(await file.exists(), isFalse);
    });
  });
}
