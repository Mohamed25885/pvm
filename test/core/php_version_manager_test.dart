import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../mocks/mock_console.dart';
import 'package:pvm/src/core/php_version_manager.dart';
import 'package:pvm/src/domain/php_version.dart';

void main() {
  late Directory tempDir;
  late MockConsole console;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pvm-phpver-');
    console = MockConsole();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('readLastUsedVersion', () {
    test('returns null when .php-version does not exist', () async {
      final manager = PhpVersionManager(console);
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, isNull);
    });

    test('returns null when .php-version is empty', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.create();
      final manager = PhpVersionManager(console);
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, isNull);
    });

    test('reads plain version string', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.writeAsString('8.2');
      final manager = PhpVersionManager(console);
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, equals(PhpVersion.parse('8.2')));
    });

    test('reads JSON version field', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.writeAsString(jsonEncode({'version': '8.3'}));
      final manager = PhpVersionManager(console);
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, equals(PhpVersion.parse('8.3')));
    });

    test('ignores extra JSON fields', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.writeAsString(jsonEncode({
        'version': '8.1',
        'someOtherField': 'ignored',
      }));
      final manager = PhpVersionManager(console);
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, equals(PhpVersion.parse('8.1')));
    });

    test('strips whitespace', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.writeAsString('  7.4  \n');
      final manager = PhpVersionManager(console);
      final result = await manager.readLastUsedVersion(rootPath: tempDir.path);
      expect(result, equals(PhpVersion.parse('7.4')));
    });
  });

  group('writeCurrentVersion', () {
    test('writes JSON with version field', () async {
      final manager = PhpVersionManager(console);
      await manager.writeCurrentVersion(
        rootPath: tempDir.path,
        version: PhpVersion.parse('8.0'),
      );

      final file = File('${tempDir.path}\\.php-version');
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      expect(decoded['version'], equals('8.0'));
    });

    test('overwrites existing content', () async {
      final file = File('${tempDir.path}\\.php-version');
      await file.writeAsString('old-version');

      final manager = PhpVersionManager(console);
      await manager.writeCurrentVersion(
        rootPath: tempDir.path,
        version: PhpVersion.parse('8.4'),
      );

      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      expect(decoded['version'], equals('8.4'));
    });
  });

  group('promptMismatch', () {
    test('returns false when stdout has no terminal', () async {
      console.hasTerminal = false;
      final manager = PhpVersionManager(console);
      final result = await manager.promptMismatch(
        currentVersion: PhpVersion.parse('8.0'),
        requestedVersion: PhpVersion.parse('8.2'),
      );
      expect(result, isFalse);
    });
  });

  group('promptVersionPick', () {
    test('returns null when stdout has no terminal', () async {
      console.hasTerminal = false;
      final manager = PhpVersionManager(console);
      final result = await manager.promptVersionPick(
        availableVersions: [PhpVersion.parse('8.0'), PhpVersion.parse('8.2')],
      );
      expect(result, isNull);
    });

    test('returns null when no versions available', () async {
      final manager = PhpVersionManager(console);
      final result = await manager.promptVersionPick(
        availableVersions: [],
      );
      expect(result, isNull);
    });
  });
}
