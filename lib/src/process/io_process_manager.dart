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
      mode: ProcessStartMode.inheritStdio,
    );
    return await process.exitCode;
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
