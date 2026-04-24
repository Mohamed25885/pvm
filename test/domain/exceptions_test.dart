import 'package:test/test.dart';
import 'package:pvm/src/domain/exceptions/pvm_exception.dart';
import 'package:pvm/src/domain/exceptions/invalid_version_format_exception.dart';
import 'package:pvm/src/domain/exceptions/version_not_installed_exception.dart';
import 'package:pvm/src/domain/exceptions/project_not_configured_exception.dart';
import 'package:pvm/src/domain/exceptions/project_configuration_exception.dart';
import 'package:pvm/src/domain/exceptions/corrupted_configuration_exception.dart';

void main() {
  group('PvmException', () {
    test('toString returns message', () {
      final ex = PvmException('test error');
      expect(ex.toString(), 'test error');
    });

    test('message property', () {
      final ex = PvmException('error message');
      expect(ex.message, 'error message');
    });
  });

  group('InvalidVersionFormatException', () {
    test('toString returns format with version', () {
      final ex = InvalidVersionFormatException('invalid');
      expect(ex.toString(), contains('invalid'));
    });
  });

  group('VersionNotInstalledException', () {
    test('includes version in message', () {
      final ex = VersionNotInstalledException('8.2');
      expect(ex.toString(), contains('8.2'));
    });
  });

  group('ProjectNotConfiguredException', () {
    test('default message', () {
      final ex = ProjectNotConfiguredException();
      expect(ex.toString(), isNotEmpty);
    });
  });

  group('ProjectConfigurationException', () {
    test('includes details', () {
      final ex = ProjectConfigurationException('invalid data');
      expect(ex.toString(), contains('invalid data'));
    });
  });

  group('CorruptedConfigurationException', () {
    test('includes path', () {
      final ex = CorruptedConfigurationException('.php-version');
      expect(ex.toString(), contains('.php-version'));
    });
  });
}
