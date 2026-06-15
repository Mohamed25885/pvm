import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('lib/src has no .php-version string literals', () {
    final libSrc = Directory(p.join(Directory.current.path, 'lib', 'src'));
    final matches = <String>[];

    for (final entity in libSrc.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      if (content.contains('.php-version')) {
        matches.add(entity.path);
      }
    }

    expect(matches, isEmpty, reason: 'Found .php-version in: $matches');
  });
}
