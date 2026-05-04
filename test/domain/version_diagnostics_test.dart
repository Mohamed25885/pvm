import 'package:test/test.dart';

import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/version_diagnostics.dart';

void main() {
  group('VersionDiagnostics.notInstalledMessage', () {
    test('formats message with installed versions list', () {
      final msg = VersionDiagnostics.notInstalledMessage(
        requested: PhpVersion.parse('8.4'),
        installed: [
          PhpVersion.parse('8.3.0'),
          PhpVersion.parse('8.2.10'),
          PhpVersion.parse('7.4.33'),
        ],
      );

      expect(msg, contains('Version 8.4 is not installed.'));
      expect(msg, contains('Installed versions: 8.3.0, 8.2.10, 7.4.33'));
    });

    test('handles empty installed list', () {
      final msg = VersionDiagnostics.notInstalledMessage(
        requested: PhpVersion.parse('8.4'),
        installed: const [],
      );

      expect(msg, contains('Version 8.4 is not installed.'));
      expect(msg, contains('No PHP versions installed.'));
    });

    test('preserves order of installed list (caller-controlled sort)', () {
      final msg = VersionDiagnostics.notInstalledMessage(
        requested: PhpVersion.parse('9.0'),
        installed: [
          PhpVersion.parse('7.4'),
          PhpVersion.parse('8.2'),
        ],
      );

      expect(msg, contains('Installed versions: 7.4, 8.2'));
    });

    test('includes patch in version display when present', () {
      final msg = VersionDiagnostics.notInstalledMessage(
        requested: PhpVersion.parse('8.2.99'),
        installed: [PhpVersion.parse('8.2.10')],
      );

      expect(msg, contains('Version 8.2.99 is not installed.'));
      expect(msg, contains('Installed versions: 8.2.10'));
    });
  });
}
