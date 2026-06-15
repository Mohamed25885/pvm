abstract class IEnvironmentConfigurator {
  Future<String?> getUserEnvironmentVariable(String name);

  Future<void> setUserEnvironmentVariable(String name, String value);

  Future<String> getPath();

  Future<void> ensurePathEntries(List<String> entries);

  bool get canPersistEnvironment;
}
