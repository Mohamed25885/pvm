class ProcessSpec {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;

  ProcessSpec({
    required this.executable,
    List<String> arguments = const [],
    this.workingDirectory,
    Map<String, String>? environment,
  })  : arguments = List.unmodifiable(arguments),
        environment =
            environment == null ? null : Map.unmodifiable(environment);
}

class CapturedProcessResult {
  final String stdout;
  final String stderr;
  final int exitCode;

  const CapturedProcessResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
}

abstract class IProcessManager {
  Future<int> runInteractive(ProcessSpec spec);
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec);
}
