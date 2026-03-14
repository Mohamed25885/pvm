import 'dart:io';

class PhpProcessRunner {
  Future<int> run(String phpExePath, List<String> args) async {
    final process = await Process.start(
      phpExePath,
      args,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;
    return exitCode;
  }

  void dispose() {
    // Cleanup if needed
  }
}
