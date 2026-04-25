import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../domain/php_release.dart';
import '../interfaces/i_installer.dart';

class InstallCommand extends Command<int> {
  @override
  final String name = 'install';

  @override
  final String description = 'Download and install a PHP version';

  @override
  final ArgParser argParser = ArgParser(allowTrailingOptions: true)
    ..addOption('arch', help: 'Architecture (x64 or x86)', defaultsTo: 'x64')
    ..addFlag('ts', help: 'Thread Safe (default: NTS)', negatable: false)
    ..addFlag('nts', help: 'Non-Thread Safe', negatable: false)
    ..addFlag('force', help: 'Force reinstall', negatable: false);

  final Console _console;
  final IInstaller _installer;

  InstallCommand(
    this._console,
    this._installer,
  );

  @override
  Future<int> run() async {
    final versionArg = argResults?.rest.singleOrNull;

    if (versionArg == null) {
      _console.printError('No version specified. Usage: pvm install <version>');
      return ExitCode.usageError;
    }

    final parsed = _parseVersion(versionArg);
    if (parsed == null) {
      _console.printError('Invalid version format. Use major.minor[.patch]');
      return ExitCode.usageError;
    }

    String archStr = argResults?['arch']?.toString() ?? 'x64';
    if (archStr.isEmpty) {
      archStr = _getDefaultArchitecture();
    }

    final arch = PhpRelease.architectureFromString(archStr);
    if (arch == null) {
      _console.printError('Invalid architecture: $archStr');
      return ExitCode.usageError;
    }

    final useTs = argResults?['ts'] == true;
    final useNts = argResults?['nts'] == true;
    if (useTs && useNts) {
      _console.printError('Cannot specify both --ts and --nts');
      return ExitCode.usageError;
    }

    BuildType buildType = BuildType.nts;
    if (useTs) buildType = BuildType.ts;

    final force = argResults?['force'] == true;

    try {
      final options = InstallOptions(
        architecture: arch,
        buildType: buildType,
        force: force,
      );

      await _installer.install(versionArg, options: options);

      _console.print('Successfully installed PHP $versionArg');
      return ExitCode.success;
    } on Exception catch (e) {
      // The installer should have printed or thrown specific errors.
      _console.printError('Installation failed: $e');
      return ExitCode.generalError;
    } finally {
      try {
        await _installer.dispose();
      } catch (_) {}
    }
  }

  (int, int, int?)? _parseVersion(String version) {
    final parts = version.split('.');
    if (parts.length < 2) return null;

    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    if (major == null || minor == null) return null;

    int? patch;
    if (parts.length > 2) {
      patch = int.tryParse(parts[2]);
    }

    return (major, minor, patch);
  }

  String _getDefaultArchitecture() {
    return 'x64';
  }
}
