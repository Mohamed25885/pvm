import 'package:test/test.dart';
import 'package:pvm/src/core/platform_constants.dart';
import 'package:pvm/src/core/platform_info.dart';

void main() {
  group('PlatformConstants', () {
    test('phpExecutableName returns php.exe for Windows', () {
      final constants = PlatformConstants(WindowsPlatformInfo());
      expect(constants.phpExecutableName, 'php.exe');
    });

    test('phpExecutableName returns php for Linux', () {
      final constants = PlatformConstants(LinuxPlatformInfo());
      expect(constants.phpExecutableName, 'php');
    });

    test('composerPharName is composer.phar', () {
      final constants = PlatformConstants(WindowsPlatformInfo());
      expect(constants.composerPharName, 'composer.phar');
    });

    test('composerBatName is composer.bat', () {
      final constants = PlatformConstants(WindowsPlatformInfo());
      expect(constants.composerBatName, 'composer.bat');
    });

    test('composerCmdName is composer.cmd', () {
      final constants = PlatformConstants(WindowsPlatformInfo());
      expect(constants.composerCmdName, 'composer.cmd');
    });

    test('composerCandidates delegates to platform', () {
      final constants = PlatformConstants(WindowsPlatformInfo());
      expect(constants.composerCandidates, contains('composer.bat'));
    });

    test('pathSeparator delegates to platform', () {
      final constants = PlatformConstants(WindowsPlatformInfo());
      expect(constants.pathSeparator, ';');
    });

    test('homeDirectoryKey delegates to platform', () {
      final constants = PlatformConstants(WindowsPlatformInfo());
      expect(constants.homeDirectoryKey, 'USERPROFILE');
    });

    test('osType delegates to platform', () {
      final constants = PlatformConstants(WindowsPlatformInfo());
      expect(constants.osType, 'windows');
    });

    test('defaultArchitecture is x64', () {
      final constants = PlatformConstants(WindowsPlatformInfo());
      expect(constants.defaultArchitecture, 'x64');
    });
  });
}
