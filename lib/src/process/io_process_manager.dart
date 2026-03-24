import 'dart:async';
import 'dart:io';

import '../core/process_manager.dart';

class IOProcessManager implements IProcessManager {
  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    final process = await Process.start(
      spec.executable,
      spec.arguments,
      workingDirectory: spec.workingDirectory,
      environment: spec.environment,
      mode: ProcessStartMode.normal,
    );

    final stdinSubscription = _tryPipeParentStdin(process);
    final stdoutDone = stdout.addStream(process.stdout);
    final stderrDone = stderr.addStream(process.stderr);

    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    await stdinSubscription?.cancel();

    return exitCode;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    try {
      final result = await Process.run(
        spec.executable,
        spec.arguments,
        workingDirectory: spec.workingDirectory,
        environment: spec.environment,
        runInShell: false,
      );

      return CapturedProcessResult(
        stdout: result.stdout?.toString() ?? '',
        stderr: result.stderr?.toString() ?? '',
        exitCode: result.exitCode,
      );
    } on ProcessException catch (error) {
      throw Exception(
        'Failed to start process "${spec.executable}": ${error.message}',
      );
    }
  }

  StreamSubscription<List<int>>? _tryPipeParentStdin(Process process) {
    try {
      return stdin.listen(
        (data) {
          try {
            process.stdin.add(data);
          } catch (_) {
            // Best-effort stdin piping for interactive mode only.
          }
        },
        onDone: () {
          process.stdin.close();
        },
      );
    } catch (_) {
      return null;
    }
  }
}
