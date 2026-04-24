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
        environment = environment == null ? null : Map.unmodifiable(environment);
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

  /// Resolve a system command name to a full executable path when possible.
  ///
  /// Implementations should avoid spawning subprocesses (e.g. `where`/`which`)
  /// and prefer deterministic resolution using known paths and PATH lookup.
  Future<String> resolveSystemCommand(String command);
}
