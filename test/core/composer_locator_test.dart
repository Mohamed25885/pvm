import 'package:test/test.dart';

import 'package:pvm/src/core/composer_locator.dart';
import 'package:pvm/src/core/platform_constants.dart';
import 'package:pvm/src/core/platform_info.dart';

import '../services/fake_os_manager.dart';

void main() {
  group('ComposerLocator (Windows)', () {
    late FakeOSManager osManager;
    late ComposerLocator locator;

    setUp(() {
      osManager = FakeOSManager();
      locator = ComposerLocator(
        platformConstants: PlatformConstants(WindowsPlatformInfo()),
        osManager: osManager,
      );
    });

    test('returns null when PATH is missing', () async {
      final result = await locator.findComposer({});
      expect(result, isNull);
    });

    test('returns null when PATH is empty string', () async {
      final result = await locator.findComposer({'PATH': ''});
      expect(result, isNull);
    });

    test('returns null when no candidate is found in PATH', () async {
      final result = await locator.findComposer({'PATH': r'C:\nope'});
      expect(result, isNull);
    });

    test('finds composer.phar directly when present', () async {
      osManager.setFileExists(r'C:\bin\composer.phar', true);

      final result = await locator.findComposer({'PATH': r'C:\bin'});

      expect(result, equals(r'C:\bin\composer.phar'));
    });

    test('finds composer.bat and resolves to composer.phar in same dir',
        () async {
      osManager.setFileExists(r'C:\bin\composer.bat', true);
      osManager.setFileExists(r'C:\bin\composer.phar', true);

      final result = await locator.findComposer({'PATH': r'C:\bin'});

      expect(result, equals(r'C:\bin\composer.phar'),
          reason: '.bat shim should resolve to its sibling .phar');
    });

    test(
        'returns the .bat path when no sibling composer.phar exists '
        '(preserves existing behavior)', () async {
      osManager.setFileExists(r'C:\bin\composer.bat', true);

      final result = await locator.findComposer({'PATH': r'C:\bin'});

      expect(result, equals(r'C:\bin\composer.bat'));
    });

    test('searches multiple directories in PATH order', () async {
      osManager.setFileExists(r'C:\second\composer.phar', true);

      final result =
          await locator.findComposer({'PATH': r'C:\first;C:\second;C:\third'});

      expect(result, equals(r'C:\second\composer.phar'));
    });

    test('first hit wins when multiple PATH entries contain composer',
        () async {
      osManager.setFileExists(r'C:\first\composer.phar', true);
      osManager.setFileExists(r'C:\second\composer.phar', true);

      final result =
          await locator.findComposer({'PATH': r'C:\first;C:\second'});

      expect(result, equals(r'C:\first\composer.phar'));
    });

    test('candidate order is bat, cmd, phar (Windows constants)', () {
      final constants = PlatformConstants(WindowsPlatformInfo());
      expect(
        constants.composerCandidates,
        equals(['composer.bat', 'composer.cmd', 'composer.phar']),
      );
    });
  });
}
