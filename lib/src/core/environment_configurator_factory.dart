import '../interfaces/i_environment_configurator.dart';
import '../managers/noop_environment_configurator.dart';
import '../managers/windows_environment_configurator.dart';
import 'platform_detector.dart';

IEnvironmentConfigurator createEnvironmentConfigurator() {
  if (PlatformDetector.isWindows) {
    return WindowsEnvironmentConfigurator();
  }
  return NoopEnvironmentConfigurator();
}
