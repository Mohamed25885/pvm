import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../domain/exceptions.dart';
import '../domain/php_release.dart';
import '../domain/php_version.dart';
import '../interfaces/i_installer.dart';
import '../services/release_fetcher.dart';
import '../core/error_text.dart';

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
    ..addFlag('force', help: 'Force reinstall', negatable: false)
    ..addFlag(
      'allow-unverified',
      help:
          'Allow archived builds that have no published SHA-256 '
          '(older patch releases).',
      negatable: false,
    );

  final Console _console;
  final IInstaller _installer;

  InstallCommand(this._console, this._installer);

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      _console.printError('No version specified. Usage: pvm install <version>');
      return ExitCode.usageError;
    }
    if (rest.length > 1) {
      _console.printError('Too many arguments. Usage: pvm install <version>');
      return ExitCode.usageError;
    }

    final PhpVersion version;
    try {
      version = PhpVersion.parse(rest.single);
    } on InvalidVersionFormatException catch (e) {
      _console.printError(e.message);
      return ExitCode.usageError;
    }

    final archStr = argResults?['arch']?.toString() ?? 'x64';
    final arch = PhpRelease.architectureFromString(
      archStr.isEmpty ? 'x64' : archStr,
    );
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

    final options = InstallOptions(
      architecture: arch,
      buildType: useTs ? BuildType.ts : BuildType.nts,
      force: argResults?['force'] == true,
      allowUnverified: argResults?['allow-unverified'] == true,
    );

    try {
      final result = await _installer.install(
        version.toString(),
        options: options,
      );
      if (result.alreadyInstalled) {
        _console.print(
          'PHP ${result.version} is already installed. '
          'Use --force to reinstall.',
        );
      } else {
        _console.print('Successfully installed PHP ${result.version}');
      }
      return ExitCode.success;
    } on ReleaseFetcherException catch (e) {
      _console.printError('Network error: ${e.message}');
      return ExitCode.generalError;
    } on NoMatchingReleaseException catch (e) {
      _console.printError(e.message);
      _console.print('Run "pvm list-remote" to see available versions.');
      return ExitCode.versionNotFound;
    } on UnverifiedReleaseException catch (e) {
      _console.printError(e.toString());
      return ExitCode.generalError;
    } on Exception catch (e) {
      _console.printError('Installation failed: ${describeError(e)}');
      return ExitCode.generalError;
    } finally {
      try {
        await _installer.dispose();
      } catch (_) {}
    }
  }
}
