import 'package:test/test.dart';

import 'package:pvm/src/domain/installed_version_resolver.dart';
import 'package:pvm/src/domain/php_version.dart';

void main() {
  group('InstalledVersionResolver.resolve', () {
    final only841 = [PhpVersion.parse('8.4.1')];
    final two84 = [PhpVersion.parse('8.4.0'), PhpVersion.parse('8.4.1')];
    final mixed = [
      PhpVersion.parse('8.3.0'),
      PhpVersion.parse('8.4.0'),
      PhpVersion.parse('8.4.1'),
    ];

    test('exact match when patch specified', () {
      final requested = PhpVersion.parse('8.4.1');
      final result = InstalledVersionResolver.resolve(requested, only841);
      expect(result, isA<ResolvedInstalledVersion>());
      expect((result as ResolvedInstalledVersion).version, equals(requested));
    });

    test('a full patch resolves to the one slot of its minor', () {
      final requested = PhpVersion.parse('8.4.1');
      final result = InstalledVersionResolver.resolve(requested, [
        PhpVersion.parse('8.4.0'),
      ]);
      expect(result, isA<ResolvedInstalledVersion>());
      expect((result as ResolvedInstalledVersion).version.toString(), '8.4.0');
    });

    test('a full patch resolves to a migrated slot without a record', () {
      final requested = PhpVersion.parse('8.2.28');
      final result = InstalledVersionResolver.resolve(requested, [
        PhpVersion.parse('8.2'),
      ]);
      expect((result as ResolvedInstalledVersion).version.toString(), '8.2');
    });

    test('an exact patch wins while two legacy patches conflict', () {
      final requested = PhpVersion.parse('8.4.0');
      final result = InstalledVersionResolver.resolve(requested, two84);
      expect((result as ResolvedInstalledVersion).version, requested);
    });

    test(
      'resolves major.minor when exactly one matching installed version',
      () {
        final requested = PhpVersion.parse('8.4');
        final result = InstalledVersionResolver.resolve(requested, only841);
        expect(result, isA<ResolvedInstalledVersion>());
        expect(
          (result as ResolvedInstalledVersion).version.toString(),
          '8.4.1',
        );
      },
    );

    test(
      'ambiguous when multiple share major.minor and no patch in request',
      () {
        final requested = PhpVersion.parse('8.4');
        final result = InstalledVersionResolver.resolve(requested, two84);
        expect(result, isA<AmbiguousInstalledVersion>());
        final ambiguous = result as AmbiguousInstalledVersion;
        expect(ambiguous.candidates.map((v) => v.toString()).toList(), [
          '8.4.1',
          '8.4.0',
        ]);
      },
    );

    test('not found when no installed version shares major.minor', () {
      final requested = PhpVersion.parse('8.4');
      final result = InstalledVersionResolver.resolve(requested, [
        PhpVersion.parse('8.3.0'),
      ]);
      expect(result, isA<NotFoundInstalledVersion>());
    });

    test('exact match for major.minor-only installed directory name', () {
      final requested = PhpVersion.parse('8.4');
      final installed = [PhpVersion.parse('8.4')];
      final result = InstalledVersionResolver.resolve(requested, installed);
      expect(result, isA<ResolvedInstalledVersion>());
      expect((result as ResolvedInstalledVersion).version, equals(requested));
    });

    test('ambiguous includes only same major.minor candidates', () {
      final requested = PhpVersion.parse('8.4');
      final result = InstalledVersionResolver.resolve(requested, mixed);
      expect(result, isA<AmbiguousInstalledVersion>());
      final candidates = (result as AmbiguousInstalledVersion).candidates;
      expect(candidates.every((v) => v.major == 8 && v.minor == 4), isTrue);
      expect(candidates.length, 2);
    });
  });
}
