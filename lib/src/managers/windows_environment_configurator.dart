import 'dart:io';

import 'package:path/path.dart' as p;

import '../interfaces/i_environment_configurator.dart';

class WindowsEnvironmentConfigurator implements IEnvironmentConfigurator {
  final Future<ProcessResult> Function(String executable, List<String> args)
  _runProcess;

  WindowsEnvironmentConfigurator({
    Future<ProcessResult> Function(String executable, List<String> args)?
    runProcess,
  }) : _runProcess = runProcess ?? Process.run;

  @override
  bool get canPersistEnvironment => true;

  @override
  Future<String?> getUserEnvironmentVariable(String name) async {
    final result = await _runProcess('reg', [
      'query',
      r'HKCU\Environment',
      '/v',
      name,
    ]);
    if (result.exitCode != 0) return null;
    final output = '${result.stdout}';
    final match = RegExp(
      r'REG_\w+\s+(.+)$',
      multiLine: true,
    ).firstMatch(output.trim());
    return match?.group(1)?.trim();
  }

  @override
  Future<void> setUserEnvironmentVariable(String name, String value) async {
    final result = await _runProcess('setx', [name, value]);
    if (result.exitCode != 0) {
      throw Exception('Failed to set $name: ${result.stderr}'.trim());
    }
  }

  @override
  Future<String> getPath() async =>
      (await getUserEnvironmentVariable('Path')) ?? '';

  @override
  Future<void> ensurePathEntries(List<String> entries) async {
    final current = await getPath();
    final segments = current.isEmpty
        ? <String>[]
        : current.split(';').where((s) => s.trim().isNotEmpty).toList();
    final existing = segments.map((s) => p.normalize(s).toLowerCase()).toSet();
    var changed = false;
    for (final entry in entries) {
      final normalized = p.normalize(entry).toLowerCase();
      if (!existing.contains(normalized)) {
        segments.add(p.normalize(entry));
        existing.add(normalized);
        changed = true;
      }
    }
    if (!changed) return;
    await setUserEnvironmentVariable('Path', segments.join(';'));
  }
}
