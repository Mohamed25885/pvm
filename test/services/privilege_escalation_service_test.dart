import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:pvm/src/interfaces/i_privilege_escalator.dart';
import 'package:pvm/src/services/privilege_escalation_service.dart';

import '../mocks/mock_console.dart';

class MockPrivilegeEscalator extends Mock implements IPrivilegeEscalator {}

void main() {
  setUpAll(() {
    registerFallbackValue(Future<bool>.value(false));
  });

  group('PrivilegeEscalationService', () {
    late MockConsole console;
    late MockPrivilegeEscalator escalator;
    late PrivilegeEscalationService service;

    setUp(() {
      console = MockConsole();
      escalator = MockPrivilegeEscalator();
      service = PrivilegeEscalationService(console, escalator);
    });

    test('returns action result when no error', () async {
      final value = await service.runWithElevationRetry(() async => 42);

      expect(value, 42);
      verifyNever(() => escalator.requestElevation());
    });

    test('rethrows non-permission errors without prompting', () async {
      await expectLater(
        service.runWithElevationRetry(() => throw Exception('disk full')),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('disk full'),
          ),
        ),
      );
      verifyNever(() => escalator.requestElevation());
    });

    test('rethrows permission error when no terminal', () async {
      console.hasTerminal = false;

      await expectLater(
        service.runWithElevationRetry(
          () => throw Exception('Access is denied'),
        ),
        throwsA(isA<Exception>()),
      );
      verifyNever(() => escalator.requestElevation());
    });

    test('retries after user approves elevation', () async {
      console.simulateInput('y');
      when(() => escalator.requestElevation()).thenAnswer((_) async => true);

      var calls = 0;
      final result = await service.runWithElevationRetry(() async {
        calls++;
        if (calls == 1) throw Exception('Access is denied');
        return 'ok';
      });

      expect(result, 'ok');
      expect(calls, 2);
      verify(() => escalator.requestElevation()).called(1);
    });

    test('rethrows when user declines elevation prompt', () async {
      console.simulateInput('n');

      await expectLater(
        service.runWithElevationRetry(
          () => throw Exception('privilege is not held'),
        ),
        throwsA(isA<Exception>()),
      );
      verifyNever(() => escalator.requestElevation());
    });

    test('rethrows when elevation request fails', () async {
      console.simulateInput('yes');
      when(() => escalator.requestElevation()).thenAnswer((_) async => false);

      await expectLater(
        service.runWithElevationRetry(() => throw Exception('error 1314')),
        throwsA(isA<Exception>()),
      );
      verify(() => escalator.requestElevation()).called(1);
    });
  });
}
