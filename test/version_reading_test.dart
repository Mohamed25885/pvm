import 'dart:io';

import 'package:test/test.dart';
import '../lib/src/version.dart' as version;

void main() {
  group('Version Reading Tests', () {
    test('Generated version constant matches pubspec.yaml version', () {
      // The expected version from pubspec.yaml
      const expectedVersion = version.packageVersion;
      expect(version.packageVersion, expectedVersion,
          reason:
              'packageVersion from generated version.dart should match pubspec.yaml');
    });

    test('pvm --version outputs correct version string', () async {
      final result = await Process.run('dart', ['run', 'pvm.dart', '--version']);
      expect(result.exitCode, 0,
          reason: 'pvm --version should exit with code 0');
      final output = result.stdout.toString().trim();
      expect(output, contains('PVM version: ${version.packageVersion}'),
          reason: 'Output should contain "PVM version: ${version.packageVersion}"');
    });

    test('pvm -v short flag outputs correct version string', () async {
      final result = await Process.run('dart', ['run', 'pvm.dart', '-v']);
      expect(result.exitCode, 0, reason: 'pvm -v should exit with code 0');
      final output = result.stdout.toString().trim();
      expect(output, contains('PVM version: ${version.packageVersion}'),
          reason: 'Output should contain "PVM version: ${version.packageVersion}"');
    });
  });
}
