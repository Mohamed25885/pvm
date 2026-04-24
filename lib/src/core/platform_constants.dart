import 'platform_info.dart';

class PlatformConstants {
  final PlatformInfo _platformInfo;

  PlatformConstants(this._platformInfo);

  String get phpExecutableName => 'php${_platformInfo.executableExtension}';

  String get composerPharName => 'composer.phar';

  String get composerBatName => 'composer.bat';

  String get composerCmdName => 'composer.cmd';

  List<String> get composerCandidates => _platformInfo.composerCandidates;

  String get pathSeparator => _platformInfo.pathSeparator;

  String get homeDirectoryKey => _platformInfo.homeDirectoryKey;

  String get osType => _platformInfo.osType;

  String get defaultArchitecture => 'x64';
}
