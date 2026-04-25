import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../domain/php_release.dart';
import '../services/release_fetcher.dart';

class ListRemoteCommand extends Command<int> {
  @override
  final String name = 'list-remote';

  @override
  final String description = 'List available PHP versions for download';

  @override
  final ArgParser argParser = ArgParser(allowTrailingOptions: true)
    ..addOption('arch', help: 'Filter by architecture (x64 or x86)')
    ..addOption('type', help: 'Filter by build type (ts or nts)');

  final IReleaseFetcher _fetcher;
  final Console _console;

  ListRemoteCommand(
    this._fetcher,
    this._console,
  );

  @override
  Future<int> run() async {
    try {
      _console.print('Fetching available PHP versions...');
      final releases = await _fetcher.fetchReleases();

      if (releases.isEmpty) {
        _console.print('No PHP versions available for download.');
        return ExitCode.generalError;
      }

      Architecture? archFilter;
      final archArg = argResults?['arch']?.toString();
      if (archArg != null && archArg.isNotEmpty) {
        archFilter = PhpRelease.architectureFromString(archArg);
      }

      BuildType? typeFilter;
      final typeArg = argResults?['type']?.toString();
      if (typeArg != null && typeArg.isNotEmpty) {
        typeFilter = PhpRelease.buildTypeFromString(typeArg);
      }

      var filtered = releases;
      if (archFilter != null) {
        filtered = filtered.where((r) => r.architecture == archFilter).toList();
      }
      if (typeFilter != null) {
        filtered = filtered.where((r) => r.buildType == typeFilter).toList();
      }

      final grouped = <String, List<PhpRelease>>{};
      for (final release in filtered) {
        final key = release.displayVersion;
        grouped.putIfAbsent(key, () => []).add(release);
      }

      final sortedVersions = grouped.keys.toList()
        ..sort((a, b) {
          final aParts = a.split('.').map(int.parse).toList();
          final bParts = b.split('.').map(int.parse).toList();
          for (var i = 0; i < aParts.length && i < bParts.length; i++) {
            final cmp = bParts[i].compareTo(aParts[i]);
            if (cmp != 0) return cmp;
          }
          return bParts.length.compareTo(aParts.length);
        });

      _console.print('Available PHP versions for download:');
      for (final version in sortedVersions) {
        final versionReleases = grouped[version]!;
        _console.print('  $version');
        for (final release in versionReleases) {
          final archStr =
              release.architecture == Architecture.x64 ? 'x64' : 'x86';
          final typeStr = release.buildType == BuildType.ts ? 'ts' : 'nts';
          _console
              .print('    - ${archStr}_$typeStr (${release.sizeFormatted})');
        }
      }

      return ExitCode.success;
    } on ReleaseFetcherException catch (e) {
      _console.printError(e.message);
      return ExitCode.generalError;
    } catch (e) {
      _console.printError('Failed to list releases: $e');
      return ExitCode.generalError;
    }
  }
}
