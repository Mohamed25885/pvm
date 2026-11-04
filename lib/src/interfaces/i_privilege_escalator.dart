/// Elevates the current process (e.g. UAC) after user approval.
abstract class IPrivilegeEscalator {
  /// Whether [requestElevation] can actually succeed on this platform.
  /// When false, callers must not prompt the user for elevation.
  bool get canElevate;

  /// Returns true when elevation succeeded and the caller may retry.
  Future<bool> requestElevation();
}
