import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/elevating_os_manager.dart';
import 'package:pvm/src/interfaces/i_privilege_escalator.dart';
import 'package:pvm/src/managers/windows_version_activator.dart';
import 'package:pvm/src/services/privilege_escalation_service.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

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

class _RecordingEscalator implements IPrivilegeEscalator {
  bool requested = false;

  @override
  Future<bool> requestElevation() async {
    requested = true;
    return true;
  }
}

void main() {
  group('WindowsVersionActivator elevation', () {
    late _FailOnceSymlinkMock osManager;
    late MockConsole console;
    late _RecordingEscalator escalator;

    setUp(() {
      osManager = _FailOnceSymlinkMock()
        ..symlinkSourceExistsOverride = true
        ..mockHomeDir = r'C:\Users\sam';
      console = MockConsole()..simulateInput('y');
      escalator = _RecordingEscalator();
    });

    test('activateGlobal retries after elevation approval', () async {
      final elevating = ElevatingOSManager(
        osManager,
        PrivilegeEscalationService(console, escalator),
      );
      final activator = WindowsVersionActivator(
        osManager: elevating,
        versionsPath: r'C:\pvm\versions',
        homeDirectory: r'C:\Users\sam',
      );

      await activator.activateGlobal('8.2.10');

      expect(escalator.requested, isTrue);
      expect(osManager.createdSymlinks, hasLength(1));
      final call = osManager.createdSymlinks.single;
      expect(call.version, '8.2.10');
      expect(call.from, p.join(r'C:\pvm\versions', '8.2.10'));
      expect(call.to, p.join(r'C:\Users\sam', PvmConstants.pvmDirName));
    });
  });
}
