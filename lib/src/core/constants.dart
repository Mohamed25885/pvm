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
