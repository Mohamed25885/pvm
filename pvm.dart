import 'dart:io';

import 'package:pvm/src/app.dart';

/// Dart ignores the value returned from `main`; the process exit code must
/// be set explicitly, or every failure (and PHP's own exit status from
/// `pvm php`) would surface as 0.
Future<void> main(List<String> arguments) async {
  exitCode = await runPvm(arguments);
}
