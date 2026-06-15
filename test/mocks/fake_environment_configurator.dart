import 'package:pvm/src/interfaces/i_environment_configurator.dart';

class FakeEnvironmentConfigurator implements IEnvironmentConfigurator {
  FakeEnvironmentConfigurator({
    this.canPersist = true,
    this.initialPath = '',
    this.throwOnSet = false,
    this.throwOnPath = false,
  });

  bool canPersist;
  String initialPath;
  bool throwOnSet;
  bool throwOnPath;

  final Map<String, String> variables = {};
  final List<String> pathEnsureCalls = [];

  @override
  bool get canPersistEnvironment => canPersist;

  @override
  Future<String?> getUserEnvironmentVariable(String name) async =>
      variables[name];

  @override
  Future<void> setUserEnvironmentVariable(String name, String value) async {
    if (throwOnSet) throw Exception('permission denied');
    variables[name] = value;
  }

  @override
  Future<String> getPath() async {
    if (throwOnPath) throw Exception('cannot read PATH');
    return variables['Path'] ?? initialPath;
  }

  @override
  Future<void> ensurePathEntries(List<String> entries) async {
    pathEnsureCalls.addAll(entries);
    final segments = (await getPath()).isEmpty
        ? <String>[]
        : (await getPath())
              .split(';')
              .where((s) => s.trim().isNotEmpty)
              .toList();
    for (final entry in entries) {
      if (!segments.contains(entry)) segments.add(entry);
    }
    variables['Path'] = segments.join(';');
  }
}
