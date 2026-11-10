import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/services/slot_migration.dart';

import 'fake_os_manager.dart';

void main() {
  late Directory tmp;
  late String v;
  late String home;
  late String globalLink;
  late FakeOSManager os;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pvm_slot_migration_');
    v = p.join(tmp.path, 'versions');
    home = p.join(tmp.path, 'home');
    globalLink = p.join(home, PvmConstants.pvmDirName);
    os = FakeOSManager();
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<void> slot(String name) =>
      Directory(p.join(v, name)).create(recursive: true);

  SlotMigration migration() => SlotMigration(os, v, home);

  test('renames 8.2.28 to 8.2 and repoints the global link', () async {
    await slot('8.2.28');
    os.setSymLinkTarget(globalLink, p.join(v, '8.2.28'));

    final result = await migration().run();

    expect(Directory(p.join(v, '8.2')).existsSync(), isTrue);
    expect(Directory(p.join(v, '8.2.28')).existsSync(), isFalse);
    expect(os.symlinkTargets[globalLink], p.join(v, '8.2'));
    expect(result.renamed, ['8.2.28']);
    expect(result.conflicts, isEmpty);
  });

  test('leaves a global link that targets another slot alone', () async {
    await slot('8.2.28');
    await slot('8.3');
    os.setSymLinkTarget(globalLink, p.join(v, '8.3'));

    await migration().run();

    expect(os.symlinkTargets[globalLink], p.join(v, '8.3'));
  });

  test('refuses when 8.2.27 and 8.2.28 both exist', () async {
    await slot('8.2.27');
    await slot('8.2.28');

    final result = await migration().run();

    expect(result.conflicts, ['8.2']);
    expect(result.renamed, isEmpty);
    expect(result.messages, [
      'Two patches of 8.2 are installed (8.2.27, 8.2.28). '
          'Remove one with: pvm uninstall 8.2.27',
    ]);
    expect(Directory(p.join(v, '8.2.27')).existsSync(), isTrue);
    expect(Directory(p.join(v, '8.2.28')).existsSync(), isTrue);
    expect(Directory(p.join(v, '8.2')).existsSync(), isFalse);
  });

  test('skips staging, old and plain files', () async {
    await slot('.staging-8.2.28-1');
    await slot('.old-8.2.28');
    await Directory(v).create(recursive: true);
    await File(p.join(v, '8.2.pvm-link.json')).writeAsString('{}');

    final result = await migration().run();

    expect(result.renamed, isEmpty);
    expect(result.conflicts, isEmpty);
  });

  test('second run is a no-op', () async {
    await slot('8.2.28');

    await migration().run();
    final second = await migration().run();

    expect(second.renamed, isEmpty);
    expect(second.conflicts, isEmpty);
    expect(Directory(p.join(v, '8.2')).existsSync(), isTrue);
  });

  test('does nothing when the versions dir does not exist', () async {
    final result = await migration().run();

    expect(result.renamed, isEmpty);
    expect(result.conflicts, isEmpty);
  });
}
