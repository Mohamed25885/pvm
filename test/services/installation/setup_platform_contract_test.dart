import 'package:test/test.dart';

import 'package:pvm/src/managers/noop_environment_configurator.dart';

void main() {
  group('Setup platform contract', () {
    late NoopEnvironmentConfigurator configurator;

    setUp(() {
      configurator = NoopEnvironmentConfigurator();
    });

    test('cannot persist environment', () {
      expect(configurator.canPersistEnvironment, isFalse);
    });

    test('getUserEnvironmentVariable always returns null', () async {
      expect(await configurator.getUserEnvironmentVariable('PVM_HOME'), isNull);
    });

    test('getPath returns empty string', () async {
      expect(await configurator.getPath(), '');
    });

    test('setUserEnvironmentVariable throws UnsupportedError', () {
      expect(
        () => configurator.setUserEnvironmentVariable('PVM_HOME', r'C:\pvm'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('ensurePathEntries throws UnsupportedError', () {
      expect(
        () => configurator.ensurePathEntries([r'C:\pvm']),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
