import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/version_label.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/domain/php_version.dart';
import '../support/temp_dir.dart';

void main() {
  test('label shows minor and patch', () {
    expect(versionLabel(PhpVersion(8, 5), '8.5.22'), '8.5 (8.5.22)');
    expect(versionLabel(PhpVersion(8, 5), null), '8.5');
  });

  test('installedLabel reads the slot record', () async {
    final dir = await Directory.systemTemp.createTemp('pvm_label_');
    addTearDown(() => deleteTemp(dir));
    expect(await installedLabel(PhpVersion(8, 5), dir.path), '8.5');
    await InstallRecord(
      version: '8.5.22',
      sourceUrl: '',
      archiveSha256: '',
      verified: true,
      installedAt: DateTime.utc(2026),
      files: const {},
    ).writeTo(dir.path);
    expect(
      await installedLabel(PhpVersion(8, 5), p.normalize(dir.path)),
      '8.5 (8.5.22)',
    );
  });
}
