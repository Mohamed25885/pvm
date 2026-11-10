import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Phase 2 exit criterion: the host OS is detected in exactly one place
/// (`createPlatformInfo`); everything else takes an injected `PlatformInfo`.
void main() {
  test('lib/ checks the host platform only in platform_detector/info', () {
    const allowed = {'platform_detector.dart', 'platform_info.dart'};
    final check = RegExp(r'Platform\.is[A-Z]|PlatformDetector\.');
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (allowed.contains(p.basename(entity.path))) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (check.hasMatch(lines[i])) offenders.add('${entity.path}:${i + 1}');
      }
    }

    expect(offenders, isEmpty, reason: 'Inject PlatformInfo instead');
  });
}
