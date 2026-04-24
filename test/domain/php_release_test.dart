import 'package:test/test.dart';
import 'package:pvm/src/domain/php_release.dart';

void main() {
  group('Architecture', () {
    test('architectureFromString handles x64 variants', () {
      expect(PhpRelease.architectureFromString('x64'), Architecture.x64);
      expect(PhpRelease.architectureFromString('x86_64'), Architecture.x64);
      expect(PhpRelease.architectureFromString('amd64'), Architecture.x64);
    });

    test('architectureFromString handles x86 variants', () {
      expect(PhpRelease.architectureFromString('x86'), Architecture.x86);
      expect(PhpRelease.architectureFromString('i386'), Architecture.x86);
      expect(PhpRelease.architectureFromString('i686'), Architecture.x86);
    });

    test('architectureFromString returns null for invalid', () {
      expect(PhpRelease.architectureFromString('invalid'), isNull);
    });
  });

  group('BuildType', () {
    test('buildTypeFromString handles ts', () {
      expect(PhpRelease.buildTypeFromString('ts'), BuildType.ts);
      expect(PhpRelease.buildTypeFromString('threadsafe'), BuildType.ts);
    });

    test('buildTypeFromString handles nts', () {
      expect(PhpRelease.buildTypeFromString('nts'), BuildType.nts);
    });

    test('buildTypeFromString returns null for invalid', () {
      expect(PhpRelease.buildTypeFromString('invalid'), isNull);
    });
  });

  group('PhpRelease', () {
    test('displayVersion includes patch', () {
      final release = _createRelease(major: 8, minor: 2, patch: 10);
      expect(release.displayVersion, '8.2.10');
    });

    test('displayVersion excludes null patch', () {
      final release = _createRelease(major: 8, minor: 2);
      expect(release.displayVersion, '8.2');
    });

    test('sizeFormatted returns MB for large files', () {
      final release = _createRelease(sizeBytes: 10 * 1024 * 1024);
      expect(release.sizeFormatted, contains('MB'));
    });

    test('sizeFormatted returns KB for small files', () {
      final release = _createRelease(sizeBytes: 500 * 1024);
      expect(release.sizeFormatted, contains('KB'));
    });
  });

  group('PhpReleaseFilter', () {
    test('filters by major', () {
      final filter = PhpReleaseFilter(major: 8);
      final release = _createRelease(major: 8, minor: 2);
      expect(filter.matches(release), isTrue);
    });

    test('filters by major mismatch', () {
      final filter = PhpReleaseFilter(major: 8);
      final release = _createRelease(major: 7, minor: 2);
      expect(filter.matches(release), isFalse);
    });

    test('filters by minor', () {
      final filter = PhpReleaseFilter(major: 8, minor: 2);
      final release = _createRelease(major: 8, minor: 2);
      expect(filter.matches(release), isTrue);
    });

    test('no filter matches all', () {
      final filter = const PhpReleaseFilter();
      final release = _createRelease();
      expect(filter.matches(release), isTrue);
    });
  });
}

PhpRelease _createRelease({
  int major = 8,
  int minor = 2,
  int? patch,
  int sizeBytes = 25000000,
}) {
  return PhpRelease(
    versionString: '$major.$minor',
    major: major,
    minor: minor,
    patch: patch,
    architecture: Architecture.x64,
    buildType: BuildType.ts,
    downloadUrl: 'https://test.com/php.zip',
    sha256: 'abc123',
    sizeBytes: sizeBytes,
    lastModified: DateTime(2024, 1, 1),
  );
}
