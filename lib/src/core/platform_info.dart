import 'dart:io';

abstract class PlatformInfo {
  String get osType;
  String get pathSeparator;
  String get executableExtension;
  String get homeDirectoryKey;
  List<String> get composerCandidates;
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
  List<String> get composerCandidates =>
      ['composer.bat', 'composer.cmd', 'composer.phar'];
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
}

PlatformInfo createPlatformInfo() {
  final os = Platform.operatingSystem;
  if (os == 'windows') return WindowsPlatformInfo();
  if (os == 'linux') return LinuxPlatformInfo();
  if (os == 'macos') return MacOSPlatformInfo();
  throw Exception('Unsupported platform: $os');
}
