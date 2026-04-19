import 'package:args/command_runner.dart';

import '../core/console.dart';
import '../core/exit_codes.dart';
import '../version.dart';

class VersionFlag extends Command<int> {
  @override
  final String name = 'version';

  @override
  final String description = 'Show PVM version';

  final Console _console;

  VersionFlag(this._console);

  @override
  Future<int> run() async {
    _console.print('PVM version: $packageVersion');
    return ExitCode.success;
  }
}
