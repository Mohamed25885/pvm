import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import 'package:pvm/src/commands/install_command.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/domain/php_release.dart';
import 'package:pvm/src/interfaces/i_installer.dart';
import 'package:pvm/src/services/build_tools.dart';
import 'package:pvm/src/services/release_fetcher.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_installer.dart';

class _ArmLinux extends LinuxPlatformInfo {
  @override
  String get hostArch => 'aarch64';
}

class _ScriptedInstaller extends MockInstaller {
  final Future<InstallResult> Function(String, InstallOptions?) onInstall;
  String? requested;
  InstallOptions? options;

  _ScriptedInstaller(this.onInstall);

  @override
  Future<InstallResult> install(String version, {InstallOptions? options}) {
    requested = version;
    this.options = options;
    return onInstall(version, options);
  }
}

Future<int> _run(
  MockConsole console,
  IInstaller installer,
  List<String> args, {
  PlatformInfo? platform,
  IInstaller? sourceInstaller,
}) async {
  final runner = CommandRunner<int>('pvm', 'test')
    ..addCommand(
      InstallCommand(
        console,
        installer,
        platform ?? WindowsPlatformInfo(),
        sourceInstaller: sourceInstaller,
      ),
    );
  return await runner.run(['install', ...args]) ?? -1;
}

void main() {
  late MockConsole console;

  setUp(() => console = MockConsole());

  test('B5: already installed is a success message, not an error', () async {
    final installer = _ScriptedInstaller(
      (v, _) async => const InstallResult('8.3.14', alreadyInstalled: true),
    );

    final code = await _run(console, installer, ['8.3']);

    expect(code, ExitCode.success);
    expect(console.errors, isEmpty);
    expect(console.printed.join('\n'), contains('already installed'));
    expect(console.printed.join('\n'), isNot(contains('Successfully')));
  });

  test('reports the concrete installed version', () async {
    final installer = _ScriptedInstaller(
      (v, _) async => const InstallResult('8.3.14'),
    );

    await _run(console, installer, ['8.3']);

    expect(
      console.printed.join('\n'),
      contains('Successfully installed PHP 8.3.14'),
    );
  });

  test('B6: network failure is reported as a network error', () async {
    final installer = _ScriptedInstaller(
      (v, _) async => throw const ReleaseFetcherException('offline'),
    );

    final code = await _run(console, installer, ['8.3']);

    expect(code, ExitCode.generalError);
    expect(console.errors.join(), contains('Network error'));
    expect(console.errors.join(), isNot(contains('No matching')));
  });

  test('no matching release exits with versionNotFound', () async {
    final installer = _ScriptedInstaller(
      (v, _) async => throw const NoMatchingReleaseException(
        'No matching PHP release found for 7.0',
      ),
    );

    final code = await _run(console, installer, ['7.0']);

    expect(code, ExitCode.versionNotFound);
  });

  test('unverified archive build explains --allow-unverified', () async {
    final installer = _ScriptedInstaller(
      (v, _) async => throw const UnverifiedReleaseException('8.2.0'),
    );

    final code = await _run(console, installer, ['8.2.0']);

    expect(code, ExitCode.generalError);
    expect(console.errors.join(), contains('--allow-unverified'));
  });

  test('--allow-unverified is passed through', () async {
    final installer = _ScriptedInstaller((v, _) async => InstallResult(v));

    await _run(console, installer, ['8.2.0', '--allow-unverified']);

    expect(installer.options?.allowUnverified, isTrue);
  });

  group('B10: single version parser', () {
    for (final bad in ['8', '8.3.x', '8.3.1.9', 'latest', '99999.1']) {
      test('rejects "$bad" before calling the installer', () async {
        final installer = _ScriptedInstaller((v, _) async => InstallResult(v));

        final code = await _run(console, installer, [bad]);

        expect(code, ExitCode.usageError);
        expect(installer.requested, isNull);
      });
    }

    test('normalizes input (trims) before installing', () async {
      final installer = _ScriptedInstaller((v, _) async => InstallResult(v));

      await _run(console, installer, [' 8.3 ']);

      expect(installer.requested, '8.3');
    });
  });

  test('a filled slot prints the update hint and fails', () async {
    final installer = _ScriptedInstaller(
      (v, _) async => throw const SlotFilledException('8.2', '8.2.28'),
    );

    final code = await _run(console, installer, ['8.2.29']);

    expect(code, ExitCode.generalError);
    expect(console.errors, ['8.2 is installed (8.2.28). Run: pvm update 8.2']);
  });

  group('on Linux/macOS', () {
    for (final flag in ['--ts', '--nts']) {
      test('$flag is a usage error naming Windows', () async {
        final installer = _ScriptedInstaller((v, _) async => InstallResult(v));

        final code = await _run(console, installer, [
          '8.4',
          flag,
        ], platform: _ArmLinux());

        expect(code, ExitCode.usageError);
        expect(console.errors.join(), contains('Windows-only'));
        expect(installer.requested, isNull);
      });
    }

    test('--from-source uses the source installer', () async {
      final installer = _ScriptedInstaller((v, _) async => InstallResult(v));
      final source = _ScriptedInstaller((v, _) async => InstallResult(v));

      final code = await _run(
        console,
        installer,
        ['8.4', '--from-source'],
        platform: _ArmLinux(),
        sourceInstaller: source,
      );

      expect(code, ExitCode.success);
      expect(source.requested, '8.4');
      expect(installer.requested, isNull);
    });

    test('missing build tools print the install command and fail', () async {
      final source = _ScriptedInstaller(
        (v, _) async => throw const MissingToolsException([
          're2c',
        ], 'sudo apt install re2c\nThen run the same pvm command again.'),
      );

      final code = await _run(
        console,
        _ScriptedInstaller((v, _) async => InstallResult(v)),
        ['8.4', '--from-source'],
        platform: _ArmLinux(),
        sourceInstaller: source,
      );

      expect(code, ExitCode.generalError);
      expect(console.errors.join(), contains('re2c'));
      expect(
        console.printed,
        contains('sudo apt install re2c\nThen run the same pvm command again.'),
      );
    });

    test('--arch defaults to the host architecture', () async {
      final installer = _ScriptedInstaller((v, _) async => InstallResult(v));

      await _run(console, installer, ['8.4'], platform: _ArmLinux());

      expect(installer.options?.architecture, Architecture.arm64);
    });
  });

  test('on Windows --from-source is a usage error', () async {
    final installer = _ScriptedInstaller((v, _) async => InstallResult(v));

    final code = await _run(console, installer, ['8.4', '--from-source']);

    expect(code, ExitCode.usageError);
    expect(console.errors.join(), contains('--from-source'));
    expect(installer.requested, isNull);
  });

  test('on Windows --arch still defaults to x64', () async {
    final installer = _ScriptedInstaller((v, _) async => InstallResult(v));

    await _run(console, installer, ['8.4', '--ts']);

    expect(installer.options?.architecture, Architecture.x64);
    expect(installer.options?.buildType, BuildType.ts);
  });
}
