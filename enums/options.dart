enum Options {
  global,
  use,
  php,
  help,
  list,
}

extension OptionsExtension on Options {
  String get name {
    switch (this) {
      case Options.list:
        return 'list';
      case Options.help:
        return 'help';
      case Options.global:
        return 'global';
      case Options.use:
        return 'use';
      case Options.php:
        return 'php';
    }
  }
}