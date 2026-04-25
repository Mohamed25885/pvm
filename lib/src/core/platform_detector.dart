import 'dart:io';

enum PlatformType { windows, linux, macos, unknown }

/// Single source of truth for platform detection logic.
class PlatformDetector {
  static PlatformType get current {
    final os = Platform.operatingSystem;
    if (os == 'windows') return PlatformType.windows;
    if (os == 'linux') return PlatformType.linux;
    if (os == 'macos') return PlatformType.macos;
    return PlatformType.unknown;
  }

  static bool get isWindows => current == PlatformType.windows;
  static bool get isLinux => current == PlatformType.linux;
  static bool get isMacOS => current == PlatformType.macos;
}
