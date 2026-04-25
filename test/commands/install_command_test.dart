import 'dart:io';

import 'package:test/test.dart';
import 'package:pvm/src/commands/install_command.dart';
import '../mocks/mock_console.dart';
import '../mocks/mock_installer.dart';

void main() {
  group('InstallCommand', () {
    late MockInstaller mockInstaller;

    setUp(() {
      mockInstaller = MockInstaller();
    });

    test('argParser has arch option', () {
      final cmd = InstallCommand(
        MockConsole(),
        mockInstaller,
      );

      final result = cmd.argParser.parse(['--arch', 'x64']);
      expect(result['arch'], 'x64');
    });

    test('argParser accepts --ts flag', () {
      final cmd = InstallCommand(
        MockConsole(),
        mockInstaller,
      );

      final result = cmd.argParser.parse(['--ts']);
      expect(result['ts'], isTrue);
    });

    test('argParser accepts --nts flag', () {
      final cmd = InstallCommand(
        MockConsole(),
        mockInstaller,
      );

      final result = cmd.argParser.parse(['--nts']);
      expect(result['nts'], isTrue);
    });

    test('argParser accepts --force flag', () {
      final cmd = InstallCommand(
        MockConsole(),
        mockInstaller,
      );

      final result = cmd.argParser.parse(['--force']);
      expect(result['force'], isTrue);
    });

    test('argParser accepts version argument', () {
      final cmd = InstallCommand(
        MockConsole(),
        mockInstaller,
      );

      final result = cmd.argParser.parse(['8.3']);
      expect(result.rest, contains('8.3'));
    });

    test('argParser defaults arch to x64', () {
      final cmd = InstallCommand(
        MockConsole(),
        mockInstaller,
      );

      final result = cmd.argParser.parse([]);
      expect(result['arch'], 'x64');
    });

    test('command has correct name and description', () {
      final cmd = InstallCommand(
        MockConsole(),
        mockInstaller,
      );

      expect(cmd.name, 'install');
      expect(cmd.description, contains('PHP'));
    });
  });

  group('Version parsing validation', () {
    test('valid version formats', () {
      expect(_parseVersion('8.3'), isNotNull);
      expect(_parseVersion('8.3.0'), isNotNull);
      expect(_parseVersion('7.4.33'), isNotNull);
    });

    test('invalid version formats', () {
      expect(_parseVersion('8'), isNull);
      expect(_parseVersion('stable'), isNull);
      expect(_parseVersion(''), isNull);
    });
  });
}

class MockOSManager {
  String get currentDirectory => Directory.current.path;
}

// Version parsing helper from InstallCommand
(int, int, int?)? _parseVersion(String version) {
  final parts = version.split('.');
  if (parts.length < 2) return null;

  final major = int.tryParse(parts[0]);
  final minor = int.tryParse(parts[1]);
  if (major == null || minor == null) return null;

  int? patch;
  if (parts.length > 2) {
    patch = int.tryParse(parts[2]);
  }

  return (major, minor, patch);
}
