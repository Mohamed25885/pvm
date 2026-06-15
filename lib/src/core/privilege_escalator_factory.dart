import '../interfaces/i_privilege_escalator.dart';
import '../managers/noop_privilege_escalator.dart';
import '../managers/windows_privilege_escalator.dart';
import 'platform_detector.dart';

IPrivilegeEscalator createPrivilegeEscalator() {
  if (PlatformDetector.isWindows) {
    return WindowsPrivilegeEscalator();
  }
  return NoopPrivilegeEscalator(elevationSucceeds: false);
}
