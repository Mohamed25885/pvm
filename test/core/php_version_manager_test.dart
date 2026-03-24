import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../lib/src/core/php_version_manager.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pvm-phpver-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('readLastUsedVersion', () {
    test('returns null when .php-version does not exist', () async {
      final manager = PhpVersionManager();
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, isNull);
    });

    test('returns null when .php-version is empty', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.create();
      final manager = PhpVersionManager();
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, isNull);
    });

    test('reads plain version string', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.writeAsString('8.2');
      final manager = PhpVersionManager();
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, equals('8.2'));
    });

    test('reads JSON version field', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.writeAsString(jsonEncode({'version': '8.3'}));
      final manager = PhpVersionManager();
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, equals('8.3'));
    });

    test('ignores extra JSON fields', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.writeAsString(jsonEncode({
        'version': '8.1',
        'someOtherField': 'ignored',
      }));
      final manager = PhpVersionManager();
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, equals('8.1'));
    });

    test('strips whitespace', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.writeAsString('  7.4  \n');
      final manager = PhpVersionManager();
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, equals('7.4'));
    });
  });

  group('writeCurrentVersion', () {
    test('writes JSON with version field', () async {
      final manager = PhpVersionManager();
      await manager.writeCurrentVersion(rootPath: tempDir.path, version: '8.0');

      final file = File('${tempDir.path}\\.php-version');
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      expect(decoded['version'], equals('8.0'));
    });

    test('overwrites existing content', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.writeAsString('old-version');

      final manager = PhpVersionManager();
      await manager.writeCurrentVersion(rootPath: tempDir.path, version: '8.4');

      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      expect(decoded['version'], equals('8.4'));
    });
  });

  group('promptMismatch', () {
    test('returns false when stdout has no terminal', () async {
      final manager = PhpVersionManager();
      final result = await manager.promptMismatch(
        currentVersion: '8.0',
        requestedVersion: '8.2',
      );
      expect(result, isFalse);
    });
  });

  group('promptVersionPick', () {
    test('returns null when stdout has no terminal', () async {
      final manager = PhpVersionManager();
      final result = await manager.promptVersionPick(
        availableVersions: ['8.0', '8.2'],
      );
      expect(result, isNull);
    });

    test('returns null when no versions available', () async {
      final manager = PhpVersionManager();
      final result = await manager.promptVersionPick(
        availableVersions: [],
      );
      expect(result, isNull);
    });
  });
}
