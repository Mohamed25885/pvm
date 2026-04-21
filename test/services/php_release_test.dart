import 'package:test/test.dart';

import '../../lib/src/domain/php_release.dart';

void main() {
  group('Architecture', () {
    test('architectureFromString parses x64 variants', () {
      expect(Architecture.x64, Architecture.x64);
      expect(PhpRelease.architectureFromString('x64'), Architecture.x64);
      expect(PhpRelease.architectureFromString('x86_64'), Architecture.x64);
      expect(PhpRelease.architectureFromString('amd64'), Architecture.x64);
      expect(PhpRelease.architectureFromString('X64'), Architecture.x64);
      expect(PhpRelease.architectureFromString('X86_64'), Architecture.x64);
    });

    test('architectureFromString parses x86 variants', () {
      expect(PhpRelease.architectureFromString('x86'), Architecture.x86);
      expect(PhpRelease.architectureFromString('i386'), Architecture.x86);
      expect(PhpRelease.architectureFromString('i686'), Architecture.x86);
      expect(PhpRelease.architectureFromString('X86'), Architecture.x86);
    });

    test('architectureFromString returns null for unknown', () {
      expect(PhpRelease.architectureFromString('arm64'), isNull);
      expect(PhpRelease.architectureFromString(''), isNull);
      expect(PhpRelease.architectureFromString('invalid'), isNull);
    });
  });

  group('BuildType', () {
    test('buildTypeFromString parses ts variants', () {
      expect(PhpRelease.buildTypeFromString('ts'), BuildType.ts);
      expect(PhpRelease.buildTypeFromString('threadsafe'), BuildType.ts);
      expect(PhpRelease.buildTypeFromString('TS'), BuildType.ts);
    });

    test('buildTypeFromString parses nts', () {
      expect(PhpRelease.buildTypeFromString('nts'), BuildType.nts);
      expect(PhpRelease.buildTypeFromString('NTS'), BuildType.nts);
    });

    test('buildTypeFromString returns null for unknown', () {
      expect(PhpRelease.buildTypeFromString('unknown'), isNull);
      expect(PhpRelease.buildTypeFromString(''), isNull);
    });
  });

  group('PhpRelease', () {
    test('displayVersion returns version string without patch', () {
      final release = PhpRelease(
        versionString: '8.3.0',
        major: 8,
        minor: 3,
        patch: 0,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: 'https://example.com/php.zip',
        sha256: 'abc123',
        sizeBytes: 10000000,
        lastModified: DateTime.now(),
      );
      expect(release.displayVersion, '8.3.0');
    });

    test('displayVersion returns version string with patch', () {
      final release = PhpRelease(
        versionString: '8.2.11',
        major: 8,
        minor: 2,
        patch: 11,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: 'https://example.com/php.zip',
        sha256: 'abc123',
        sizeBytes: 10000000,
        lastModified: DateTime.now(),
      );
      expect(release.displayVersion, '8.2.11');
    });

    test('sizeFormatted returns MB for large files', () {
      final release = PhpRelease(
        versionString: '8.3.0',
        major: 8,
        minor: 3,
        patch: 0,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: 'https://example.com/php.zip',
        sha256: 'abc123',
        sizeBytes: 1024 * 1024 * 25, // 25MB
        lastModified: DateTime.now(),
      );
      expect(release.sizeFormatted, '25.0MB');
    });

    test('sizeFormatted returns KB for small files', () {
      final release = PhpRelease(
        versionString: '8.3.0',
        major: 8,
        minor: 3,
        patch: 0,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: 'https://example.com/php.zip',
        sha256: 'abc123',
        sizeBytes: 1024 * 512, // 512KB
        lastModified: DateTime.now(),
      );
      expect(release.sizeFormatted, '512.0KB');
    });
  });

  group('PhpReleaseFilter', () {
    test('matches filters by major version', () {
      final filter = PhpReleaseFilter(major: 8);
      final release = PhpRelease(
        versionString: '8.3.0',
        major: 8,
        minor: 3,
        patch: 0,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: '',
        sha256: '',
        sizeBytes: 0,
        lastModified: DateTime.now(),
      );
      expect(filter.matches(release), isTrue);
    });

    test('matches filters by major and minor', () {
      final filter = PhpReleaseFilter(major: 8, minor: 3);
      final release = PhpRelease(
        versionString: '8.3.0',
        major: 8,
        minor: 3,
        patch: 0,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: '',
        sha256: '',
        sizeBytes: 0,
        lastModified: DateTime.now(),
      );
      expect(filter.matches(release), isTrue);
    });

    test('matches filters by architecture', () {
      final filter = PhpReleaseFilter(architecture: Architecture.x64);
      final release = PhpRelease(
        versionString: '8.3.0',
        major: 8,
        minor: 3,
        patch: 0,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: '',
        sha256: '',
        sizeBytes: 0,
        lastModified: DateTime.now(),
      );
      expect(filter.matches(release), isTrue);
    });

    test('matches filters by buildType', () {
      final filter = PhpReleaseFilter(buildType: BuildType.nts);
      final release = PhpRelease(
        versionString: '8.3.0',
        major: 8,
        minor: 3,
        patch: 0,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: '',
        sha256: '',
        sizeBytes: 0,
        lastModified: DateTime.now(),
      );
      expect(filter.matches(release), isTrue);
    });

    test('does not match when major differs', () {
      final filter = PhpReleaseFilter(major: 8);
      final release = PhpRelease(
        versionString: '7.4.0',
        major: 7,
        minor: 4,
        patch: 0,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: '',
        sha256: '',
        sizeBytes: 0,
        lastModified: DateTime.now(),
      );
      expect(filter.matches(release), isFalse);
    });

    test('does not match when architecture differs', () {
      final filter = PhpReleaseFilter(architecture: Architecture.x86);
      final release = PhpRelease(
        versionString: '8.3.0',
        major: 8,
        minor: 3,
        patch: 0,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: '',
        sha256: '',
        sizeBytes: 0,
        lastModified: DateTime.now(),
      );
      expect(filter.matches(release), isFalse);
    });

    test('empty filter matches all', () {
      final filter = const PhpReleaseFilter();
      final release = PhpRelease(
        versionString: '8.3.0',
        major: 8,
        minor: 3,
        patch: 0,
        architecture: Architecture.x64,
        buildType: BuildType.nts,
        downloadUrl: '',
        sha256: '',
        sizeBytes: 0,
        lastModified: DateTime.now(),
      );
      expect(filter.matches(release), isTrue);
    });
  });
}
