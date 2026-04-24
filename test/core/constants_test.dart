import 'package:test/test.dart';
import 'package:pvm/src/core/constants.dart';

void main() {
  group('PvmConstants', () {
    test('pvmDirName is .pvm', () {
      expect(PvmConstants.pvmDirName, '.pvm');
    });

    test('phpVersionFileName is .php-version', () {
      expect(PvmConstants.phpVersionFileName, '.php-version');
    });

    test('gitignoreFileName is .gitignore', () {
      expect(PvmConstants.gitignoreFileName, '.gitignore');
    });

    test('phpExecutable is php.exe', () {
      expect(PvmConstants.phpExecutable, 'php.exe');
    });

    test('composerPhar is composer.phar', () {
      expect(PvmConstants.composerPhar, 'composer.phar');
    });

    test('composerBat is composer.bat', () {
      expect(PvmConstants.composerBat, 'composer.bat');
    });

    test('composerCmd is composer.cmd', () {
      expect(PvmConstants.composerCmd, 'composer.cmd');
    });

    test('versionPattern is valid regex', () {
      final pattern = RegExp(PvmConstants.versionPattern);
      expect(pattern.hasMatch('8.2'), isTrue);
      expect(pattern.hasMatch('8.2.10'), isTrue);
      expect(pattern.hasMatch('invalid'), isFalse);
    });

    test('versionPattern captures groups', () {
      final pattern = RegExp(PvmConstants.versionPattern);
      final match = pattern.firstMatch('8.2.10');
      expect(match, isNotNull);
      expect(match!.group(1), '8');
      expect(match.group(2), '2');
      expect(match.group(3), '10');
    });

    test('versionPattern handles no patch', () {
      final pattern = RegExp(PvmConstants.versionPattern);
      final match = pattern.firstMatch('8.2');
      expect(match, isNotNull);
      expect(match!.group(3), isNull);
    });
  });
}
