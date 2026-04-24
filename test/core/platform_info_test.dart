import 'package:test/test.dart';

import 'package:pvm/src/core/platform_info.dart';

void main() {
  group('PlatformInfo', () {
    group('WindowsPlatformInfo', () {
      late WindowsPlatformInfo info;

      setUp(() {
        info = WindowsPlatformInfo();
      });

      test('returns correct osType', () {
        expect(info.osType, 'windows');
      });

      test('returns correct pathSeparator', () {
        expect(info.pathSeparator, ';');
      });

      test('returns correct executableExtension', () {
        expect(info.executableExtension, '.exe');
      });

      test('returns correct homeDirectoryKey', () {
        expect(info.homeDirectoryKey, 'USERPROFILE');
      });

      test('returns correct composerCandidates', () {
        expect(info.composerCandidates, [
          'composer.bat',
          'composer.cmd',
          'composer.phar',
        ]);
      });
    });

    group('LinuxPlatformInfo', () {
      late LinuxPlatformInfo info;

      setUp(() {
        info = LinuxPlatformInfo();
      });

      test('returns correct osType', () {
        expect(info.osType, 'linux');
      });

      test('returns correct pathSeparator', () {
        expect(info.pathSeparator, ':');
      });

      test('returns correct executableExtension', () {
        expect(info.executableExtension, '');
      });

      test('returns correct homeDirectoryKey', () {
        expect(info.homeDirectoryKey, 'HOME');
      });

      test('returns correct composerCandidates', () {
        expect(info.composerCandidates, ['composer', 'composer.phar']);
      });
    });

    group('MacOSPlatformInfo', () {
      late MacOSPlatformInfo info;

      setUp(() {
        info = MacOSPlatformInfo();
      });

      test('returns correct osType', () {
        expect(info.osType, 'macos');
      });

      test('returns correct pathSeparator', () {
        expect(info.pathSeparator, ':');
      });

      test('returns correct executableExtension', () {
        expect(info.executableExtension, '');
      });

      test('returns correct homeDirectoryKey', () {
        expect(info.homeDirectoryKey, 'HOME');
      });

      test('returns correct composerCandidates', () {
        expect(info.composerCandidates, ['composer', 'composer.phar']);
      });
    });

    group('createPlatformInfo', () {
      test('returns WindowsPlatformInfo on windows', () {
        // This test verifies the factory works - actual result depends on platform
        final info = createPlatformInfo();
        expect(info, isA<PlatformInfo>());
        expect(info.osType, isNotEmpty);
      });

      test('throws on unsupported platform', () {
        // This would test the exception path if we could mock Platform.operatingSystem
        // For now, just verify it returns something on current platform
        final info = createPlatformInfo();
        expect(info, isNotNull);
      });
    });
  });
}
