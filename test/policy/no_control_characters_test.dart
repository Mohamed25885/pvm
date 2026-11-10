import 'dart:io';

import 'package:test/test.dart';

/// Shell heredocs and `python -c` can turn `\t`, `\a`, `\b`, `\f` in edited
/// text into raw control bytes that format, analyze and tests all accept.
/// Source must contain only printable text, `\n` and `\r`.
void main() {
  test('Dart sources contain no control characters (tabs included)', () {
    final roots = [Directory('lib'), Directory('test'), File('pvm.dart')];
    final offenders = <String>[];

    for (final root in roots) {
      final files = root is Directory
          ? root.listSync(recursive: true).whereType<File>()
          : [root as File];
      for (final file in files.where((f) => f.path.endsWith('.dart'))) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final bad = lines[i].codeUnits.where((c) => c < 0x20 && c != 0x0D);
          if (bad.isNotEmpty) {
            final hex = bad.map((c) => '0x${c.toRadixString(16)}').toSet();
            offenders.add('${file.path}:${i + 1} ${hex.join(',')}');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: 'Control characters found');
  });
}
