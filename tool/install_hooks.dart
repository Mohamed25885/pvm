import 'dart:io';

/// dart_pre_commit 6 has no test task (a `test:` key in pubspec.yaml is
/// ignored), so the hook runs the suite itself after the other checks.
const hook = r'''#!/usr/bin/env bash
set -e
# Prefer the FVM-pinned SDK (.fvmrc); fall back to dart on PATH.
if command -v fvm >/dev/null 2>&1; then dart() { fvm dart "$@"; }; fi
dart run dart_pre_commit
dart test -r failures-only
''';

Future<void> main() async {
  final hookFile = File('.git/hooks/pre-commit');
  await hookFile.parent.create(recursive: true);
  await hookFile.writeAsString(hook);

  if (!Platform.isWindows) {
    await Process.run('chmod', ['+x', hookFile.path]);
  }
  print('✅ Pre-commit hook installed (dart_pre_commit + dart test)');
}
