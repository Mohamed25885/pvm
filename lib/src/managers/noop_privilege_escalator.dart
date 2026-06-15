import '../interfaces/i_privilege_escalator.dart';

/// Test/CI stub — never performs real UAC.
class NoopPrivilegeEscalator implements IPrivilegeEscalator {
  bool elevationRequested = false;
  bool elevationSucceeds;

  NoopPrivilegeEscalator({this.elevationSucceeds = true});

  @override
  Future<bool> requestElevation() async {
    elevationRequested = true;
    return elevationSucceeds;
  }
}
