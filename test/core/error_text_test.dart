import 'dart:io';

import 'package:test/test.dart';

import 'package:pvm/src/core/error_text.dart';

void main() {
  group('describeError (D8)', () {
    test('strips nested Exception:/Error: prefixes', () {
      expect(
        describeError(Exception('Error: Source directory does not exist: X')),
        'Source directory does not exist: X',
      );
    });

    test('leaves plain messages alone', () {
      expect(describeError(StateError('bad state')), 'Bad state: bad state');
      expect(describeError('just text'), 'just text');
    });

    test('unwraps FileSystemException text', () {
      expect(
        describeError(const FileSystemException('Cannot delete', r'C:\x')),
        startsWith('Cannot delete'),
      );
    });
  });
}
