import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../domain/exceptions.dart';
import '../domain/php_version.dart';

class GlobalCommand extends Command<int> {
  @override
  final String name = 'global';

  @override
  final String description = 'Set the global PHP version (system-wide)';

  final IOSManager _osManager;
  final Console _console;

  GlobalCommand(this._osManager, this._console);

  @override
  Future<int> run() async {
    try {
      if (argResults!.rest.isEmpty) {
        _console.printError('No version specified');
        _console.print('Usage: pvm global <version>');
        return ExitCode.usageError;
      }

      if (argResults!.rest.length > 1) {
        _console.printError('Too many arguments. Usage: pvm global <version>');
        return ExitCode.usageError;
      }

      final versionStr = argResults!.rest.first;
      final version = PhpVersion.parse(versionStr);

      final availableVersionStrs =
          _osManager.getAvailableVersions(_osManager.phpVersionsPath);
      if (!availableVersionStrs.contains(version.toString())) {
        _console.printError('Version $version not found.');
        _console
            .print('Available versions: ${availableVersionStrs.join(", ")}');
        return ExitCode.generalError;
      }

      final globalPath =
          _osManager.localPath; // For global, this is %USERPROFILE%\.pvm
      final versionsPath = _osManager.phpVersionsPath;
      final sourcePath = p.join(versionsPath, version.toString());

      if (!await _osManager.directoryExists(sourcePath)) {
        _console.printError('Version $version not found.');
        return ExitCode.generalError;
      }

      await _osManager.createSymLink(
        version.toString(),
        sourcePath,
        globalPath,
      );

      _console.print('Global link created:');
      _console.print('  $globalPath -> $sourcePath');
      return ExitCode.success;
    } on InvalidVersionFormatException catch (e) {
      _console.printError(e.message);
      return ExitCode.usageError;
    } on ProjectConfigurationException catch (e) {
      _console.printError(e.message);
      return ExitCode.configurationError;
    } on PvmException catch (e) {
      _console.printError(e.message);
      return ExitCode.generalError;
    }
  }
}
