import 'package:test/test.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/exceptions.dart';

void main() {
  group('PhpVersion', () {
    test('parse major.minor version', () {
      final version = PhpVersion.parse('8.2');
      expect(version.major, 8);
      expect(version.minor, 2);
      expect(version.patch, isNull);
    });

    test('parse major.minor.patch version', () {
      final version = PhpVersion.parse('8.2.10');
      expect(version.major, 8);
      expect(version.minor, 2);
      expect(version.patch, 10);
    });

    test('parse throws for invalid format', () {
      expect(
        () => PhpVersion.parse('invalid'),
        throwsA(isA<InvalidVersionFormatException>()),
      );
    });

    test('parse throws for single number', () {
      expect(
        () => PhpVersion.parse('8'),
        throwsA(isA<InvalidVersionFormatException>()),
      );
    });

    test('hasPatch returns false for minor only', () {
      final version = PhpVersion.parse('8.2');
      expect(version.hasPatch, isFalse);
    });

    test('hasPatch returns true for patch version', () {
      final version = PhpVersion.parse('8.2.10');
      expect(version.hasPatch, isTrue);
    });

    test('isAtLeast with major only', () {
      final version = PhpVersion.parse('8.2');
      expect(version.isAtLeast(8), isTrue);
      expect(version.isAtLeast(9), isFalse);
    });

    test('isAtLeast with major.minor', () {
      final version = PhpVersion.parse('8.2');
      expect(version.isAtLeast(8, 2), isTrue);
      expect(version.isAtLeast(8, 3), isFalse);
    });

    test('compareTo sorts by major', () {
      final v80 = PhpVersion.parse('8.0');
      final v82 = PhpVersion.parse('8.2');
      expect(v80.compareTo(v82), lessThan(0));
      expect(v82.compareTo(v80), greaterThan(0));
    });

    test('compareTo sorts by minor when major equal', () {
      final v82 = PhpVersion.parse('8.2');
      final v83 = PhpVersion.parse('8.3');
      expect(v82.compareTo(v83), lessThan(0));
    });

    test('equality works', () {
      final v1 = PhpVersion.parse('8.2.10');
      final v2 = PhpVersion.parse('8.2.10');
      final v3 = PhpVersion.parse('8.2.11');
      expect(v1 == v2, isTrue);
      expect(v1 == v3, isFalse);
    });

    test('hashCode consistent with equality', () {
      final v1 = PhpVersion.parse('8.2.10');
      final v2 = PhpVersion.parse('8.2.10');
      expect(v1.hashCode, v2.hashCode);
    });

    test('toString returns full format with patch', () {
      final version = PhpVersion.parse('8.2.10');
      expect(version.toString(), '8.2.10');
    });

    test('toString returns short format without patch', () {
      final version = PhpVersion.parse('8.2');
      expect(version.toString(), '8.2');
    });

    test('toShortString always returns major.minor', () {
      final version = PhpVersion.parse('8.2.10');
      expect(version.toShortString(), '8.2');
    });
  });
}
