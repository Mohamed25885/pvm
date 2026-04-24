import 'dart:io';

import '../core/os_manager.dart';
import '../managers/windows_os_manager.dart';
import '../managers/linux_os_manager.dart';
import '../managers/mac_os_manager.dart';

IOSManager createOSManager() {
  final os = Platform.operatingSystem;
  if (os == 'windows') return WindowsOSManager();
  if (os == 'linux') return LinuxOSManager();
  if (os == 'macos') return MacOSManager();
  throw Exception('Unsupported platform: $os');
}
