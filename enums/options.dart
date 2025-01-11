enum Options {
  version,
  use,
  php,
}

extension OptionsExtension on Options {
  String get name {
    switch (this) {
      case Options.version:
        return 'version';
      case Options.use:
        return 'use';
      case Options.php:
        return 'php';
    }
  }
}