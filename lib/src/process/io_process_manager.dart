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

    // Forward stdin from parent to child (best-effort, non-blocking)
    _forwardStdin(process.stdin);

    // Pipe child stdout and stderr to parent
    final stdoutFuture = process.stdout.pipe(stdout);
    final stderrFuture = process.stderr.pipe(stderr);

    await Future.wait([stdoutFuture, stderrFuture]);
    return await process.exitCode;
  }

  void _forwardStdin(IOSink stdinSink) {
    // Fire-and-forget stdin forwarding
    Future(() async {
      try {
        await for (final data in stdin) {
          stdinSink.add(data);
        }
        await stdinSink.flush();
        await stdinSink.close();
      } catch (_) {
        // Best-effort: ignore any errors in stdin forwarding
      }
    });
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
}
