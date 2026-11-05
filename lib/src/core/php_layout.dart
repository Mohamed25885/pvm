import 'package:path/path.dart' as p;

import 'platform_info.dart';

/// Where the PHP binary lives inside an installed version directory.
///
/// * Windows builds (windows.php.net ZIPs): `<versionDir>\php.exe`
/// * Unix builds (`--prefix=<versionDir>` / static builds): `<versionDir>/bin/php`
///
/// Every component that turns a version directory (or a `.pvm` link to one)
/// into a PHP path must go through this class (roadmap 2.1, D5).
class PhpLayout {
  /// Sub-directory holding the executables; empty when they sit at the root.
  final String binSubdirectory;

  /// File name of the PHP CLI binary (`php.exe` / `php`).
  final String executableName;

  const PhpLayout({
    required this.binSubdirectory,
    required this.executableName,
  });

  static const windows = PhpLayout(
    binSubdirectory: '',
    executableName: 'php.exe',
  );

  static const unix = PhpLayout(binSubdirectory: 'bin', executableName: 'php');

  factory PhpLayout.forPlatform(PlatformInfo info) =>
      info.osType == 'windows' ? windows : unix;

  /// Directory to put on `PATH` for [versionDir].
  String binDirectory(String versionDir) => binSubdirectory.isEmpty
      ? versionDir
      : p.join(versionDir, binSubdirectory);

  /// Full path of the PHP binary for [versionDir].
  String phpExecutable(String versionDir) =>
      p.join(binDirectory(versionDir), executableName);
}
