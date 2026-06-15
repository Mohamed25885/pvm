import '../interfaces/i_environment_configurator.dart';

class NoopEnvironmentConfigurator implements IEnvironmentConfigurator {
  @override
  bool get canPersistEnvironment => false;

  @override
  Future<String?> getUserEnvironmentVariable(String name) async => null;

  @override
  Future<void> setUserEnvironmentVariable(String name, String value) async {
    throw UnsupportedError(
      'Environment configuration is not supported on this platform.',
    );
  }

  @override
  Future<String> getPath() async => '';

  @override
  Future<void> ensurePathEntries(List<String> entries) async {
    throw UnsupportedError('PATH configuration is not supported.');
  }
}
