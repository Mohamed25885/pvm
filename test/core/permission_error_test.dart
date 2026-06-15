import 'package:test/test.dart';

import 'package:pvm/src/core/permission_error.dart';

void main() {
  group('isPermissionDenied', () {
    test('returns true for access is denied', () {
      expect(isPermissionDenied(Exception('Access is denied')), isTrue);
    });

    test('returns true for access denied', () {
      expect(isPermissionDenied(Exception('access denied')), isTrue);
    });

    test('returns true for privilege is not held', () {
      expect(
        isPermissionDenied(Exception('A required privilege is not held')),
        isTrue,
      );
    });

    test('returns true for error 1314', () {
      expect(isPermissionDenied(Exception('Win32 error 1314')), isTrue);
    });

    test('returns true for elevation required', () {
      expect(isPermissionDenied(Exception('Elevation required')), isTrue);
    });

    test('returns false for unrelated errors', () {
      expect(isPermissionDenied(Exception('File not found')), isFalse);
      expect(isPermissionDenied(StateError('bad state')), isFalse);
    });
  });
}
