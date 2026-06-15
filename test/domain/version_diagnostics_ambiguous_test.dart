import 'package:test/test.dart';

import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/version_diagnostics.dart';

void main() {
  group('VersionDiagnostics.ambiguousVersionMessage', () {
    test('lists matches newest-first and suggests full version', () {
      final message = VersionDiagnostics.ambiguousVersionMessage(
        requested: PhpVersion.parse('8.4'),
        matches: [PhpVersion.parse('8.4.1'), PhpVersion.parse('8.4.0')],
      );
      expect(message, contains('8.4'));
      expect(message, contains('ambiguous'));
      expect(message, contains('8.4.1'));
      expect(message, contains('8.4.0'));
      expect(message, contains('8.4.1'));
    });
  });
}
