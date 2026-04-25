
import '../core/os_manager.dart';
import '../core/platform_detector.dart';
import '../managers/windows_os_manager.dart';
import '../managers/linux_os_manager.dart';
import '../managers/mac_os_manager.dart';

IOSManager createOSManager() {
  final platform = PlatformDetector.current;
  if (platform == PlatformType.windows) return WindowsOSManager();
  if (platform == PlatformType.linux) return LinuxOSManager();
  if (platform == PlatformType.macos) return MacOSManager();
  throw Exception('Unsupported platform');
}
