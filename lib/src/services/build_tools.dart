import 'dart:io';

import '../core/platform_info.dart';
import '../core/process_manager.dart';

/// Thrown when building PHP needs tools or headers the system lacks.
/// [installCommand] is the exact command for the user to run; PVM never runs
/// it (no sudo, no system packages).
class MissingToolsException implements Exception {
  final List<String> missing;
  final String installCommand;
  const MissingToolsException(this.missing, this.installCommand);

  @override
  String toString() =>
      'Missing build tools: ${missing.join(', ')}\n$installCommand';
}

/// Checks for the system's build tools before a source build and names the
/// platform's own install command when something is missing.
class BuildTools {
  final IProcessManager _pm;
  final PlatformInfo _platform;
  final String osReleasePath;

  BuildTools(
    this._pm,
    this._platform, {
    this.osReleasePath = '/etc/os-release',
  });

  static const _again = 'Then run the same pvm command again.';

  /// Base packages, then the full dev list, per package-manager family.
  static const _families = <String, (String, String)>{
    'apt': (
      'sudo apt install build-essential autoconf bison re2c pkg-config',
      'libxml2-dev libsqlite3-dev libssl-dev libcurl4-openssl-dev libonig-dev '
          'libzip-dev libicu-dev libpng-dev libjpeg-dev libfreetype6-dev '
          'libwebp-dev libsodium-dev libpq-dev libreadline-dev zlib1g-dev '
          'libgmp-dev libxslt1-dev',
    ),
    'dnf': (
      'sudo dnf install gcc make autoconf bison re2c pkgconf',
      'libxml2-devel sqlite-devel openssl-devel libcurl-devel oniguruma-devel '
          'libzip-devel libicu-devel libpng-devel libjpeg-turbo-devel '
          'freetype-devel libwebp-devel libsodium-devel libpq-devel '
          'readline-devel zlib-devel gmp-devel libxslt-devel',
    ),
    'pacman': (
      'sudo pacman -S base-devel re2c',
      'libxml2 sqlite openssl curl oniguruma libzip icu libpng libjpeg-turbo '
          'freetype2 libwebp libsodium postgresql-libs readline zlib gmp '
          'libxslt',
    ),
    'apk': (
      'sudo apk add build-base autoconf bison re2c pkgconf',
      'libxml2-dev sqlite-dev openssl-dev curl-dev oniguruma-dev libzip-dev '
          'icu-dev libpng-dev libjpeg-turbo-dev freetype-dev libwebp-dev '
          'libsodium-dev libpq-dev readline-dev zlib-dev gmp-dev libxslt-dev',
    ),
    'brew': (
      'xcode-select --install\nbrew install autoconf bison re2c pkg-config',
      'libxml2 sqlite openssl@3 curl oniguruma libzip icu4c libpng jpeg '
          'freetype webp libsodium libpq readline zlib gmp libxslt libiconv',
    ),
  };

  static const _distros = {
    'ubuntu': 'apt',
    'debian': 'apt',
    'fedora': 'dnf',
    'rhel': 'dnf',
    'centos': 'dnf',
    'arch': 'pacman',
    'alpine': 'apk',
  };

  /// Throws [MissingToolsException] unless every one of [tools] is on PATH
  /// and every pkg-config module in [devPackages] (the dev packages' `.pc`
  /// names, e.g. `libxml-2.0`) exists.
  Future<void> require(
    List<String> tools, {
    List<String> devPackages = const [],
  }) async {
    final missingTools = [
      for (final t in tools)
        if (!await _ok('sh', ['-c', 'command -v "\$1"', 'sh', t])) t,
    ];
    final havePkgConfig =
        devPackages.isEmpty ||
        await _ok('sh', ['-c', 'command -v "\$1"', 'sh', 'pkg-config']);
    final missingDev = [
      for (final m in devPackages)
        if (!havePkgConfig || !await _ok('pkg-config', ['--exists', m])) m,
    ];
    final missing = [...missingTools, ...missingDev];
    if (missing.isEmpty) return;

    final family = _platform.osType == 'macos' ? 'brew' : await _linuxFamily();
    final packages = _families[family];
    final command = packages == null
        ? 'Install with your system package manager: ${missing.join(' ')}'
        : missingDev.isEmpty
        ? packages.$1
        : '${packages.$1} ${packages.$2}';
    throw MissingToolsException(missing, '$command\n$_again');
  }

  Future<bool> _ok(String exe, List<String> args) async {
    try {
      final r = await _pm.runCaptured(
        ProcessSpec(executable: exe, arguments: args),
      );
      return r.exitCode == 0;
    } on Exception {
      return false;
    }
  }

  /// `ID`, then each `ID_LIKE` entry, of `/etc/os-release`.
  Future<String?> _linuxFamily() async {
    final file = File(osReleasePath);
    if (!await file.exists()) return null;
    final fields = <String, String>{};
    for (final line in await file.readAsLines()) {
      final i = line.indexOf('=');
      if (i <= 0) continue;
      fields[line.substring(0, i).trim()] = line
          .substring(i + 1)
          .trim()
          .replaceAll(RegExp('^["\']|["\']\$'), '');
    }
    final ids = [?fields['ID'], ...?fields['ID_LIKE']?.split(RegExp(r'\s+'))];
    for (final id in ids) {
      final family = _distros[id.toLowerCase()];
      if (family != null) return family;
    }
    return null;
  }
}
