import '../interfaces/i_privilege_escalator.dart';

/// Windows UAC elevation hook (production stub — no in-process elevation).
class WindowsPrivilegeEscalator implements IPrivilegeEscalator {
  @override
  Future<bool> requestElevation() async => false;
}
