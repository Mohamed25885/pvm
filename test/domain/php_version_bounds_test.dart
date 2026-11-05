import 'package:test/test.dart';

import 'package:pvm/src/domain/exceptions.dart';
import 'package:pvm/src/domain/php_version.dart';

void main() {
  group('B9: PhpVersion.parse bounds', () {
    test('huge numbers are an InvalidVersionFormatException, not overflow', () {
      expect(
        () => PhpVersion.parse('99999999999999999999.1'),
        throwsA(isA<InvalidVersionFormatException>()),
      );
      expect(
        () => PhpVersion.parse('8.3.123456'),
        throwsA(isA<InvalidVersionFormatException>()),
      );
    });

    test('four-digit parts still parse', () {
      expect(PhpVersion.parse('8.3.1000').patch, 1000);
    });
  });
}
