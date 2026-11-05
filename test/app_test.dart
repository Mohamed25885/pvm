import 'package:pvm/src/app.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/managers/linux_installer.dart';
import 'package:pvm/src/managers/macos_installer.dart';
import 'package:pvm/src/managers/noop_environment_configurator.dart';
import 'package:pvm/src/managers/windows_environment_configurator.dart';
import 'package:pvm/src/managers/windows_installer.dart';
import 'package:test/test.dart';

import 'mocks/mock_console.dart';
import 'mocks/mock_os_manager.dart';

PvmDependencies _deps(PlatformInfo platform, MockConsole console) =>
    PvmDependencies.forHost(
      platform: platform,
      console: console,
      osManager: MockOSManager(),
      processManager: MockProcessManager(),
    );

void main() {
  group('composition root (2.7)', () {
    test('buildRunner wires every command', () {
      final runner = buildRunner(_deps(WindowsPlatformInfo(), MockConsole()));

      expect(
        runner.commands.keys,
        containsAll([
          'install',
          'list-remote',
          'use',
          'global',
          'list',
          'current',
          'doctor',
          'uninstall',
          'exec',
          'php',
          'composer',
          'setup',
        ]),
      );
    });

    test('platform implementations follow PlatformInfo, not the host', () {
      final console = MockConsole();
      final windows = _deps(WindowsPlatformInfo(), console);
      final linux = _deps(LinuxPlatformInfo(), console);
      final macos = _deps(MacOSPlatformInfo(), console);

      expect(windows.installer, isA<WindowsInstaller>());
      expect(
        windows.environmentConfigurator,
        isA<WindowsEnvironmentConfigurator>(),
      );
      expect(linux.installer, isA<LinuxInstaller>());
      expect(linux.environmentConfigurator, isA<NoopEnvironmentConfigurator>());
      expect(macos.installer, isA<MacOSInstaller>());
    });

    test('runPvm --version prints the version and exits 0', () async {
      final console = MockConsole();

      final code = await runPvm([
        '--version',
      ], deps: _deps(LinuxPlatformInfo(), console));

      expect(code, ExitCode.success);
      expect(console.printed.join(), contains('PVM version:'));
    });

    test('runPvm maps an unknown command to a usage error', () async {
      final console = MockConsole();

      final code = await runPvm([
        'no-such-command',
      ], deps: _deps(LinuxPlatformInfo(), console));

      expect(code, ExitCode.usageError);
      expect(console.errors.join(), contains('no-such-command'));
    });
  });
}
