enum Options {
  global,
  use,
  php,
}

extension OptionsExtension on Options {
  String get name {
    switch (this) {
      case Options.global:
        return 'global';
      case Options.use:
        return 'use';
      case Options.php:
        return 'php';
    }
  }
}