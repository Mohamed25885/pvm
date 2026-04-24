import 'package:test/test.dart';
import 'package:pvm/src/core/exit_codes.dart';

void main() {
  group('ExitCode', () {
    test('success is 0', () {
      expect(ExitCode.success, 0);
    });

    test('generalError is 1', () {
      expect(ExitCode.generalError, 1);
    });

    test('usageError is 2', () {
      expect(ExitCode.usageError, 2);
    });

    test('versionNotFound is 3', () {
      expect(ExitCode.versionNotFound, 3);
    });

    test('userCancelled is 4', () {
      expect(ExitCode.userCancelled, 4);
    });

    test('permissionDenied is 5', () {
      expect(ExitCode.permissionDenied, 5);
    });

    test('configurationError is 6', () {
      expect(ExitCode.configurationError, 6);
    });
  });
}
