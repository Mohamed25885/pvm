import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Builds pvm into `builds/` for this machine, plus Linux x64 and arm64,
/// and writes `builds/SHA256SUMS` (the `sha256sum -c` format).
///
/// Run: `fvm dart run tool/build.dart`. It compiles with the same SDK that
/// runs it. Dart cross-compiles only to Linux, so the Windows and macOS
/// binaries come from building on those machines (or CI).
Future<void> main() async {
  final host = Abi.current().toString().split('_'); // e.g. [windows, x64]
  final targets = <(String, String)>{
    (host[0], host[1]),
    ('linux', 'x64'),
    ('linux', 'arm64'),
  };

  await Directory('builds').create();
  final sums = StringBuffer();
  for (final (os, arch) in targets) {
    final name = 'pvm-$os-$arch${os == 'windows' ? '.exe' : ''}';
    final cross = (os, arch) != (host[0], host[1]);
    stdout.writeln('Building $name ...');
    final r = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      if (cross) ...['--target-os=$os', '--target-arch=$arch'],
      'pvm.dart',
      '-o',
      'builds/$name',
    ]);
    if (r.exitCode != 0) {
      stderr.writeln('${r.stdout}${r.stderr}');
      exit(r.exitCode);
    }
    final digest = sha256.convert(await File('builds/$name').readAsBytes());
    sums.write('$digest  $name\n');
  }
  await File('builds/SHA256SUMS').writeAsString(sums.toString());
  stdout.write('\nbuilds/SHA256SUMS:\n$sums');
}
