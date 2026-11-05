import '../interfaces/i_privilege_escalator.dart';

/// Windows: PVM cannot elevate an already-running process. Local and global
/// links are created as directory junctions (no privilege needed); only the
/// symlink fallback can hit a permission error, and then the user is told how
/// to fix it (Developer Mode or an Administrator terminal) instead of being
/// shown an elevation prompt that cannot work.
class WindowsPrivilegeEscalator implements IPrivilegeEscalator {
  @override
  bool get canElevate => false;

  @override
  Future<bool> requestElevation() async => false;
}
