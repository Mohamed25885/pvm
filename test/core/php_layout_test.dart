import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/executable_resolver.dart';
import 'package:pvm/src/core/php_layout.dart';
import 'package:pvm/src/core/platform_constants.dart';
import 'package:pvm/src/core/platform_info.dart';

import '../services/fake_os_manager.dart';

void main() {
  group('PhpLayout (2.1)', () {
    test('Windows: php.exe at the version root, root is the PATH dir', () {
      const layout = PhpLayout.windows;
      final dir = p.join('versions', '8.3.14');

      expect(layout.binDirectory(dir), dir);
      expect(layout.phpExecutable(dir), p.join(dir, 'php.exe'));
    });

    test('Unix: bin/php, bin/ is the PATH dir', () {
      const layout = PhpLayout.unix;
      final dir = p.join('versions', '8.3.14');

      expect(layout.binDirectory(dir), p.join(dir, 'bin'));
      expect(layout.phpExecutable(dir), p.join(dir, 'bin', 'php'));
    });

    test('forPlatform picks the layout from PlatformInfo', () {
      expect(PhpLayout.forPlatform(WindowsPlatformInfo()), PhpLayout.windows);
      expect(PhpLayout.forPlatform(LinuxPlatformInfo()), PhpLayout.unix);
      expect(PhpLayout.forPlatform(MacOSPlatformInfo()), PhpLayout.unix);
    });
  });

  group('ExecutableResolver uses the layout through the .pvm link', () {
    test('Unix resolves <project>/.pvm/bin/php (B16)', () async {
      final os = FakeOSManager();
      final project = p.join('home', 'me', 'app');
      final expected = p.join(project, '.pvm', 'bin', 'php');
      os.setFileExists(expected, true);
      final resolver = ExecutableResolver(
        platformConstants: PlatformConstants(LinuxPlatformInfo()),
        osManager: os,
      );

      expect(await resolver.resolvePhpExecutable(project), expected);
    });

    test('Windows resolves <project>/.pvm/php.exe', () async {
      final os = FakeOSManager();
      final project = p.join('C:', 'app');
      final expected = p.join(project, '.pvm', 'php.exe');
      os.setFileExists(expected, true);
      final resolver = ExecutableResolver(
        platformConstants: PlatformConstants(WindowsPlatformInfo()),
        osManager: os,
      );

      expect(await resolver.resolvePhpExecutable(project), expected);
    });
  });
}
