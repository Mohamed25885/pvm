/// Elevates the current process (e.g. UAC) after user approval.
abstract class IPrivilegeEscalator {
  /// Returns true when elevation succeeded and the caller may retry.
  Future<bool> requestElevation();
}
