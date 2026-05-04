/// Severity of a single diagnostic check.
enum DiagnosticStatus {
  ok,
  info,
  warn,
  fail,
}

/// One row in the `pvm doctor` report.
class DiagnosticResult {
  final String id;
  final String label;
  final DiagnosticStatus status;
  final List<String> lines;

  const DiagnosticResult({
    required this.id,
    required this.label,
    required this.status,
    this.lines = const [],
  });

  bool get isFail => status == DiagnosticStatus.fail;
}
