import 'dart:ffi';

import 'package:pvm/src/core/platform_detector.dart';

abstract class PlatformInfo {
  String get osType;
  String get pathSeparator;
  String get executableExtension;
  String get homeDirectoryKey;
  List<String> get composerCandidates;
  String get hostArch;
}

/// Arch names used in static-php URLs (`x86_64` / `aarch64`).
String hostArchFor(Abi abi) {
  if (abi == Abi.linuxX64 || abi == Abi.macosX64 || abi == Abi.windowsX64) {
    return 'x86_64';
  }
  if (abi == Abi.linuxArm64 ||
      abi == Abi.macosArm64 ||
      abi == Abi.windowsArm64) {
    return 'aarch64';
  }
  return abi.toString();
}

class WindowsPlatformInfo implements PlatformInfo {
  @override
  String get osType => 'windows';

  @override
  String get pathSeparator => ';';

  @override
  String get executableExtension => '.exe';

  @override
  String get homeDirectoryKey => 'USERPROFILE';

  @override
  List<String> get composerCandidates => [
    'composer.bat',
    'composer.cmd',
    'composer.phar',
  ];

  @override
  String get hostArch => hostArchFor(Abi.current());
}

class LinuxPlatformInfo implements PlatformInfo {
  @override
  String get osType => 'linux';

  @override
  String get pathSeparator => ':';

  @override
  String get executableExtension => '';

  @override
  String get homeDirectoryKey => 'HOME';

  @override
  List<String> get composerCandidates => ['composer', 'composer.phar'];

  @override
  String get hostArch => hostArchFor(Abi.current());
}

class MacOSPlatformInfo implements PlatformInfo {
  @override
  String get osType => 'macos';

  @override
  String get pathSeparator => ':';

  @override
  String get executableExtension => '';

  @override
  String get homeDirectoryKey => 'HOME';

  @override
  List<String> get composerCandidates => ['composer', 'composer.phar'];

  @override
  String get hostArch => hostArchFor(Abi.current());
}

PlatformInfo createPlatformInfo() {
  final platform = PlatformDetector.current;
  if (platform == PlatformType.windows) return WindowsPlatformInfo();
  if (platform == PlatformType.linux) return LinuxPlatformInfo();
  if (platform == PlatformType.macos) return MacOSPlatformInfo();
  throw Exception('Unsupported platform');
}
