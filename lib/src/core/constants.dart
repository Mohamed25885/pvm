/// Application-wide constants for PVM.
class PvmConstants {
  // Directory and file names
  static const pvmDirName = '.pvm';
  static const phpVersionFileName = '.php-version';
  static const gitignoreFileName = '.gitignore';

  // Executables (Windows)
  static const phpExecutable = 'php.exe';
  static const composerPhar = 'composer.phar';
  static const composerBat = 'composer.bat';
  static const composerCmd = 'composer.cmd';

  // Version format (with capture groups: major, minor, optional patch)
  static const versionPattern = r'^(\d+)\.(\d+)(?:\.(\d+))?$';
}

class PvmUrls {
  static const windowsReleasesApi = 'https://downloads.php.net/~windows/releases/releases.json';
  static const windowsDownloadBase = 'https://windows.php.net/downloads/releases/';
}

class PvmTimeouts {
  static const downloadTimeoutSeconds = 300;
  static const downloadMaxRetries = 3;
}

class PvmMessages {
  // Can be filled with error message templates.
}
