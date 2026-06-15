import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/pvm_paths.dart';

import '../mocks/mock_os_manager.dart';

void main() {
  group('PvmPaths.fromEnvironment', () {
    test('uses programDirectoryFallback when env vars unset', () {
      final osManager = MockOSManager()..mockProgramDir = r'C:\tools\pvm';
      osManager.mockEnvironment = {};

      final paths = PvmPaths.fromEnvironment(
        osManager.currentEnvironment,
        programDirectoryFallback: osManager.programDirectory,
      );

      expect(paths.pvmHome, p.normalize(r'C:\tools\pvm'));
      expect(paths.versionsHome, p.normalize(r'C:\tools\pvm\versions'));
    });

    test('respects PVM_HOME and defaults versions under home', () {
      final paths = PvmPaths.fromEnvironment({
        PvmConstants.envPvmHome: r'D:\custom\pvm',
      }, programDirectoryFallback: r'C:\ignored');

      expect(paths.pvmHome, p.normalize(r'D:\custom\pvm'));
      expect(paths.versionsHome, p.normalize(r'D:\custom\pvm\versions'));
    });

    test('respects PVM_VERSIONS_HOME override', () {
      final paths = PvmPaths.fromEnvironment({
        PvmConstants.envPvmHome: r'C:\pvm',
        PvmConstants.envPvmVersionsHome: r'E:\php-versions',
      }, programDirectoryFallback: r'C:\fallback');

      expect(paths.pvmHome, p.normalize(r'C:\pvm'));
      expect(paths.versionsHome, p.normalize(r'E:\php-versions'));
    });

    test('treats blank env values as unset', () {
      final paths = PvmPaths.fromEnvironment({
        PvmConstants.envPvmHome: '   ',
        PvmConstants.envPvmVersionsHome: '',
      }, programDirectoryFallback: r'C:\pvm\bin');

      expect(paths.pvmHome, p.normalize(r'C:\pvm\bin'));
      expect(paths.versionsHome, p.normalize(r'C:\pvm\bin\versions'));
    });

    test('normalizes home and versions paths', () {
      final paths = PvmPaths.fromEnvironment({
        PvmConstants.envPvmHome: r'C:\pvm\..\pvm',
      }, programDirectoryFallback: r'C:\unused');

      expect(paths.pvmHome, p.normalize(r'C:\pvm\..\pvm'));
      expect(
        paths.versionsHome,
        p.normalize(p.join(paths.pvmHome, 'versions')),
      );
    });
  });
}
