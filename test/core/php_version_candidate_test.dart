import 'package:test/test.dart';
import 'package:pvm/src/core/php_version_candidate.dart';

void main() {
  group('PhpVersionCandidate', () {
    test('normalize removes patch version', () {
      expect(PhpVersionCandidate.normalize('8.4.1'), equals('8.4'));
    });

    test('normalize handles minor version only', () {
      expect(PhpVersionCandidate.normalize('8.4'), equals('8.4'));
    });

    test('normalize removes php@ prefix', () {
      expect(PhpVersionCandidate.normalize('php@8.4'), equals('8.4'));
    });

    test('normalize removes php prefix', () {
      expect(PhpVersionCandidate.normalize('php8.4'), equals('8.4'));
    });

    test('constructor stores values', () {
      const candidate = PhpVersionCandidate(
        version: '8.4',
        rawName: 'php@8.4',
        source: 'brew',
        isInstalled: false,
      );

      expect(candidate.version, equals('8.4'));
      expect(candidate.rawName, equals('php@8.4'));
      expect(candidate.source, equals('brew'));
      expect(candidate.isInstalled, isFalse);
    });

    test('toString returns formatted string', () {
      const candidate = PhpVersionCandidate(
        version: '8.4',
        rawName: 'php@8.4',
        source: 'brew',
        isInstalled: false,
      );

      expect(
          candidate.toString(), equals('PhpVersionCandidate(8.4 from brew)'));
    });
  });
}
