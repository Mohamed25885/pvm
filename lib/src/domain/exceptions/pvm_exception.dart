/// Base exception for all PVM domain errors.
class PvmException implements Exception {
  final String message;
  const PvmException(this.message);

  @override
  String toString() => message;
}
