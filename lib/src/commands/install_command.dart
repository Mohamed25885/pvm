import 'dart:io';
import 'package:archive/archive.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../domain/php_release.dart';
import '../interfaces/i_installer.dart';
import '../services/release_fetcher.dart';

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

  final IReleaseFetcher _fetcher;
  final Console _console;
  final IInstaller _installer;

  InstallCommand(
    this._fetcher,
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

    final (major, minor, patch) = parsed;

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
    final versionsPath = _installer.versionsPath;

    try {
      _console.print('Fetching available PHP versions...');
      final releases = await _fetcher.fetchReleases();

      final filter = PhpReleaseFilter(
        major: major,
        minor: minor,
        patch: patch,
        architecture: arch,
        buildType: buildType,
      );

      final matching = releases.where((r) => filter.matches(r)).toList();

      if (matching.isEmpty) {
        _console.printError('No matching PHP release found');
        return ExitCode.generalError;
      }

      final release = matching.first;
      final versionDir = p.join(versionsPath, release.displayVersion);

      if (!force && await Directory(versionDir).exists()) {
        _console.printError('PHP ${release.displayVersion} already installed. Use --force to reinstall');
        return ExitCode.generalError;
      }

      // Lifecycle hook: before installation starts
      await _installer.preInstall(release.displayVersion);

      _console.print('Downloading PHP ${release.displayVersion}...');
      // Lifecycle hook: download started
      await _installer.onInstalling(release.displayVersion, 0.0);
      final zipFile = await _installer.downloadPhp(release, versionsPath);

      _console.print('Verifying SHA256...');
      final valid = await _installer.verifySha256(zipFile, release.sha256);
      if (!valid) {
        await zipFile.delete();
        _console.printError('SHA256 verification failed');
        // Lifecycle hook: on failure
        await _installer.onInstallFailed(release.displayVersion, Exception('SHA256 verification failed'));
        return ExitCode.generalError;
      }

      _console.print('Extracting...');
      // Lifecycle hook: after extraction
      await _installer.onInstalling(release.displayVersion, 0.5);
      await _extractZip(zipFile.path, versionDir);
      await zipFile.delete();

      // Lifecycle hook: on success
      await _installer.postInstall(release.displayVersion);

      _console.print('Successfully installed PHP ${release.displayVersion}');
      return ExitCode.success;
    } on ReleaseFetcherException catch (e) {
      _console.printError(e.message);
      await _installer.onInstallFailed(versionArg, e);
      return ExitCode.generalError;
    } on DownloadException catch (e) {
      _console.printError(e.message);
      await _installer.onInstallFailed(versionArg, e);
      return ExitCode.generalError;
    } catch (e) {
      _console.printError('Installation failed: $e');
      await _installer.onInstallFailed(versionArg, Exception(e.toString()));
      return ExitCode.generalError;
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

  Future<void> _extractZip(String zipPath, String destPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final destDir = Directory(p.normalize(destPath));
    final destCanonical = destDir.path;

    for (final file in archive.files) {
      final filename = file.name;
      final fullPath = p.join(destPath, filename);
      final normalizedPath = p.normalize(fullPath);

      if (!normalizedPath.startsWith(destCanonical) && normalizedPath != destCanonical) {
        continue;
      }

      if (filename.endsWith('/')) {
        await Directory(fullPath).create(recursive: true);
      } else {
        await Directory(p.dirname(fullPath)).create(recursive: true);
        await File(fullPath).writeAsBytes(file.content);
      }
    }
  }
}
