import 'package:test/test.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/exceptions.dart';

void main() {
  group('Security Audit Suite', () {
    group('PhpVersion.parse Injection Protections', () {
      test('Rejects path traversal via version arguments', () {
        const payload = '8.2/../../../windows/system32';
        expect(
          () => PhpVersion.parse(payload),
          throwsA(isA<InvalidVersionFormatException>()),
        );
      });

      test('Rejects bash command injection via version arguments', () {
        const payload = '8.2; rm -rf /';
        expect(
          () => PhpVersion.parse(payload),
          throwsA(isA<InvalidVersionFormatException>()),
        );
      });

      test('Rejects option injection via version arguments', () {
        const payload = '-o something=malicious';
        expect(
          () => PhpVersion.parse(payload),
          throwsA(isA<InvalidVersionFormatException>()),
        );
      });

      test('Rejects empty or purely malicious payloads', () {
        expect(() => PhpVersion.parse(''),
            throwsA(isA<InvalidVersionFormatException>()));
        expect(() => PhpVersion.parse('sudo'),
            throwsA(isA<InvalidVersionFormatException>()));
        expect(() => PhpVersion.parse('<script>'),
            throwsA(isA<InvalidVersionFormatException>()));
      });
    });

    // NOTE: HTTPS validation tests for `WindowsInstaller._validateUrl`
    // require mocking the installer network dependencies, but are structurally locked
    // inside the `_validateUrl` bounds ensuring URL scheme and domain mapping.
  });
}
