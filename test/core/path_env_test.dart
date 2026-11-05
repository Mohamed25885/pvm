import 'package:test/test.dart';

import 'package:pvm/src/core/path_env.dart';

void main() {
  group('prependToPath', () {
    test('reuses the Windows "Path" key instead of adding PATH', () {
      final env = prependToPath(
        {'Path': r'C:\Windows;C:\bin', 'HOME': 'x'},
        r'C:\pvm\versions\8.3.14',
        separator: ';',
        caseInsensitiveKeys: true,
      );

      expect(env.keys, unorderedEquals(['Path', 'HOME']));
      expect(env['Path'], r'C:\pvm\versions\8.3.14;C:\Windows;C:\bin');
    });

    test('moves an existing occurrence to the front (no duplicates)', () {
      final env = prependToPath(
        {'PATH': r'C:\a;C:\PVM\versions\8.3.14;C:\b'},
        r'C:\pvm\versions\8.3.14',
        separator: ';',
        caseInsensitiveKeys: true,
      );

      expect(env['PATH'], r'C:\pvm\versions\8.3.14;C:\a;C:\b');
    });

    test('creates PATH when missing', () {
      final env = prependToPath({}, '/opt/php/bin', separator: ':');
      expect(env['PATH'], '/opt/php/bin');
    });

    test('does not mutate the input map', () {
      final input = {'PATH': '/usr/bin'};
      prependToPath(input, '/opt/php/bin', separator: ':');
      expect(input['PATH'], '/usr/bin');
    });
  });
}
