import '../interfaces/i_privilege_escalator.dart';
import '../managers/noop_privilege_escalator.dart';
import '../managers/windows_privilege_escalator.dart';
import 'platform_info.dart';

IPrivilegeEscalator createPrivilegeEscalator([PlatformInfo? platform]) {
  if ((platform ?? createPlatformInfo()).osType == 'windows') {
    return WindowsPrivilegeEscalator();
  }
  return NoopPrivilegeEscalator(elevationSucceeds: false);
}
