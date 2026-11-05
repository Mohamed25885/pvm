/// Application-wide constants for PVM.
class PvmConstants {
  // Directory and file names
  static const pvmDirName = '.pvm';
  static const pvmrcFileName = '.pvmrc';
  static const gitignoreFileName = '.gitignore';

  static const envPvmHome = 'PVM_HOME';
  static const envPvmVersionsHome = 'PVM_VERSIONS_HOME';

  // Executables (Windows)
  static const phpExecutable = 'php.exe';
  static const composerPhar = 'composer.phar';
  static const composerBat = 'composer.bat';
  static const composerCmd = 'composer.cmd';

  // Version format (with capture groups: major, minor, optional patch).
  // Parts are bounded to 4 digits so int.parse can never overflow.
  static const versionPattern = r'^(\d{1,4})\.(\d{1,4})(?:\.(\d{1,4}))?$';
}

class PvmUrls {
  static const windowsReleasesApi =
      'https://downloads.php.net/~windows/releases/releases.json';
  static const windowsDownloadBase =
      'https://windows.php.net/downloads/releases/';
  static const windowsArchivesListing =
      'https://downloads.php.net/~windows/releases/archives/';
  static const windowsArchivesDownloadBase =
      'https://downloads.php.net/~windows/releases/archives/';
}

class PvmTimeouts {
  static const downloadTimeoutSeconds = 300;
  static const downloadMaxRetries = 3;
}

class PvmMessages {
  // Can be filled with error message templates.
}
