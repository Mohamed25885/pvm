import 'dart:io';

Future<void> main() async {
  final hookFile = File('.git/hooks/pre-commit');
  await hookFile.parent.create(recursive: true);
  await hookFile
      .writeAsString('#!/usr/bin/env bash\nexec dart run dart_pre_commit\n');

  if (!Platform.isWindows) {
    await Process.run('chmod', ['+x', hookFile.path]);
  }
  print('✅ Pre-commit hook installed');
}
