import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../domain/exceptions.dart';
import '../domain/php_version.dart';

class ListCommand extends Command<int> {
  @override
  final String name = 'list';

  @override
  final String description = 'List all available PHP versions';

  @override
  ArgParser get argParser => ArgParser(allowTrailingOptions: true);

  final IOSManager _osManager;
  final Console _console;

  ListCommand(this._osManager, this._console);

  @override
  Future<int> run() async {
    final versionStrings =
        _osManager.getAvailableVersions(_osManager.phpVersionsPath);
    final List<PhpVersion> versions = [];

    for (final versionStr in versionStrings) {
      try {
        final version = PhpVersion.parse(versionStr);
        versions.add(version);
      } on InvalidVersionFormatException {
        // Skip invalid version entries
      }
    }

    if (versions.isEmpty) {
      return ExitCode.generalError;
    }

    versions.sort((a, b) => b.compareTo(a));

    _console.print('Available PHP versions:');
    for (final version in versions) {
      _console.print('  - ${version.toString()}');
    }

    return ExitCode.success;
  }
}
