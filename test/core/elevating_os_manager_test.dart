import 'package:test/test.dart';

import 'package:pvm/src/core/elevating_os_manager.dart';
import 'package:pvm/src/interfaces/i_privilege_escalator.dart';
import 'package:pvm/src/services/privilege_escalation_service.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

/// Fails the first [createSymLink] with a permission error, then delegates.
class _FailOnceSymlinkMock extends MockOSManager {
  int _attempts = 0;

  @override
  Future<({String from, String to})> createSymLink(
    String version,
    String from,
    String to,
  ) async {
    _attempts++;
    if (_attempts == 1) {
      throw Exception('Access is denied');
    }
    return super.createSymLink(version, from, to);
  }
}

class _ApprovingEscalator implements IPrivilegeEscalator {
  int requestCount = 0;

  @override
  Future<bool> requestElevation() async {
    requestCount++;
    return true;
  }
}

void main() {
  group('ElevatingOSManager', () {
    late _FailOnceSymlinkMock delegate;
    late MockConsole console;
    late _ApprovingEscalator escalator;
    late ElevatingOSManager manager;

    setUp(() {
      delegate = _FailOnceSymlinkMock()..symlinkSourceExistsOverride = true;
      console = MockConsole()..simulateInput('yes');
      escalator = _ApprovingEscalator();
      manager = ElevatingOSManager(
        delegate,
        PrivilegeEscalationService(console, escalator),
      );
    });

    test(
      'retries createSymLink after elevation on permission denial',
      () async {
        final result = await manager.createSymLink(
          '8.2',
          r'C:\versions\8.2',
          r'C:\project\.pvm',
        );

        expect(result.from, r'C:\versions\8.2');
        expect(result.to, r'C:\project\.pvm');
        expect(delegate.symlinkCallCount, 1);
        expect(escalator.requestCount, 1);
        expect(delegate.createdSymlinks, hasLength(1));
      },
    );

    test('rethrows when user declines elevation', () async {
      final denied = MockOSManager()
        ..shouldThrowOnSymlink = true
        ..symlinkErrorMessage = 'Access is denied';
      final decliningConsole = MockConsole()..simulateInput('n');
      final decliningEscalator = _ApprovingEscalator();
      final declining = ElevatingOSManager(
        denied,
        PrivilegeEscalationService(decliningConsole, decliningEscalator),
      );

      await expectLater(
        declining.createSymLink('8.2', r'C:\from', r'C:\to'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Access is denied'),
          ),
        ),
      );
      expect(decliningEscalator.requestCount, 0);
    });

    test('delegates directoryExists to inner manager', () async {
      delegate.setDirectoryExistsResult(r'C:\pvm', true);

      expect(await manager.directoryExists(r'C:\pvm'), isTrue);
      expect(delegate.directoryExistsCallCount, 1);
    });
  });
}
