import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import '../../lib/src/managers/mock_os_manager.dart';
import '../../lib/src/process/io_process_manager.dart';
import '../../pvm.dart';

void main() {
  group('Version flag tests', () {
    late PvmCommandRunner runner;
    late MockOSManager osManager;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pvm-version-test-');
      osManager = MockOSManager();
      osManager.mockCurrentDirectory = tempDir.path;

      runner = PvmCommandRunner(
        osManager: osManager,
        processManager: IOProcessManager(),
        mockCurrentDirectory: tempDir.path,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('--version flag prints version and exits with 0', () async {
      final output = <String>[];

      await runZoned(
        () async {
          final result = await runner.run(['--version']);
          expect(result, 0);
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            output.add(line);
          },
        ),
      );

      expect(output.join('\n'), contains('PVM version: 1.0.0'));
    });

    test('-v short flag prints version and exits with 0', () async {
      final output = <String>[];

      await runZoned(
        () async {
          final result = await runner.run(['-v']);
          expect(result, 0);
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            output.add(line);
          },
        ),
      );

      expect(output.join('\n'), contains('PVM version: 1.0.0'));
    });

    test('--version takes precedence over command arguments', () async {
      final output = <String>[];

      await runZoned(
        () async {
          final result = await runner.run(['--version', 'global', '8.2']);
          expect(result, 0);
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            output.add(line);
          },
        ),
      );

      final outputText = output.join('\n');
      expect(outputText, contains('PVM version: 1.0.0'));
      expect(outputText, isNot(contains('Global link created')));
    });

    test('--help still works as before', () async {
      final output = <String>[];

      await runZoned(
        () async {
          final result = await runner.run(['--help']);
          expect(result, 0);
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            output.add(line);
          },
        ),
      );

      final helpText = output.join('\n');
      expect(helpText, contains('PHP Version Manager'));
      expect(helpText, contains('global'));
      expect(helpText, contains('use'));
      expect(helpText, contains('list'));
      expect(helpText, contains('php'));
      expect(helpText, contains('composer'));
      // Should NOT show version
      expect(helpText, isNot(contains('PVM version:')));
    });
  });
}
