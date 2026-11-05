import '../interfaces/i_environment_configurator.dart';
import '../managers/noop_environment_configurator.dart';
import '../managers/windows_environment_configurator.dart';
import 'platform_info.dart';

IEnvironmentConfigurator createEnvironmentConfigurator([
  PlatformInfo? platform,
]) {
  if ((platform ?? createPlatformInfo()).osType == 'windows') {
    return WindowsEnvironmentConfigurator();
  }
  return NoopEnvironmentConfigurator();
}
