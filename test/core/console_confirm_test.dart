import 'package:test/test.dart';

import 'package:pvm/src/core/console.dart';

import '../mocks/mock_console.dart';

void main() {
  group('Console.confirm (default no)', () {
    test('returns false when no terminal attached', () async {
      final console = MockConsole();
      console.hasTerminal = false;
      console.simulateInput('y');

      final result = await console.confirm('Delete?');

      expect(result, isFalse);
    });

    test('returns false on empty input', () async {
      final console = MockConsole();
      console.simulateInput('');

      final result = await console.confirm('Delete?');

      expect(result, isFalse);
    });

    test('returns false on whitespace input', () async {
      final console = MockConsole();
      console.simulateInput('   ');

      final result = await console.confirm('Delete?');

      expect(result, isFalse);
    });

    test('returns true on "y"', () async {
      final console = MockConsole();
      console.simulateInput('y');

      expect(await console.confirm('Delete?'), isTrue);
    });

    test('returns true on "Y" (case-insensitive)', () async {
      final console = MockConsole();
      console.simulateInput('Y');

      expect(await console.confirm('Delete?'), isTrue);
    });

    test('returns true on "yes"', () async {
      final console = MockConsole();
      console.simulateInput('yes');

      expect(await console.confirm('Delete?'), isTrue);
    });

    test('returns false on "no"', () async {
      final console = MockConsole();
      console.simulateInput('no');

      expect(await console.confirm('Delete?'), isFalse);
    });

    test('returns false on arbitrary input', () async {
      final console = MockConsole();
      console.simulateInput('maybe');

      expect(await console.confirm('Delete?'), isFalse);
    });

    test('appends (y/N) suffix to prompt', () async {
      final console = MockConsole();
      console.simulateInput('n');

      await console.confirm('Delete?');

      expect(console.lastPrompt, contains('Delete?'));
      expect(console.lastPrompt, contains('(y/N)'));
    });
  });

  group('Console.confirm (default yes)', () {
    test('returns true when no terminal attached', () async {
      final console = MockConsole();
      console.hasTerminal = false;

      expect(await console.confirm('Continue?', defaultYes: true), isTrue);
    });

    test('returns true on empty input', () async {
      final console = MockConsole();
      console.simulateInput('');

      expect(await console.confirm('Continue?', defaultYes: true), isTrue);
    });

    test('returns false on "n"', () async {
      final console = MockConsole();
      console.simulateInput('n');

      expect(await console.confirm('Continue?', defaultYes: true), isFalse);
    });

    test('appends (Y/n) suffix when defaultYes is true', () async {
      final console = MockConsole();
      console.simulateInput('');

      await console.confirm('Continue?', defaultYes: true);

      expect(console.lastPrompt, contains('(Y/n)'));
    });
  });
}
