import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/link_slot.dart';
import 'package:pvm/src/domain/exceptions.dart';

void main() {
  group('clearLinkSlot (S2)', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('pvm_slot_');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('is a no-op when nothing exists', () async {
      await clearLinkSlot(p.join(temp.path, '.pvm'));
    });

    test('refuses to delete a real directory and keeps its contents', () async {
      final slot = Directory(p.join(temp.path, '.pvm'));
      await slot.create();
      final precious = File(p.join(slot.path, 'precious.txt'));
      await precious.writeAsString('keep me');

      await expectLater(
        clearLinkSlot(slot.path),
        throwsA(isA<LinkSlotOccupiedException>()),
      );
      expect(await precious.readAsString(), 'keep me');
    });

    test('refuses to delete a real file', () async {
      final slot = File(p.join(temp.path, '.pvm'));
      await slot.writeAsString('x');

      await expectLater(
        clearLinkSlot(slot.path),
        throwsA(isA<LinkSlotOccupiedException>()),
      );
      expect(await slot.exists(), isTrue);
    });

    test('removes an existing link but not its target', () async {
      final target = Directory(p.join(temp.path, 'target'));
      await target.create();
      await File(p.join(target.path, 'php.exe')).writeAsString('');
      final slot = p.join(temp.path, '.pvm');
      try {
        await Link(slot).create(target.path);
      } on FileSystemException {
        markTestSkipped('symlinks need Developer Mode or admin on Windows');
        return;
      }

      await clearLinkSlot(slot);

      expect(
        await FileSystemEntity.type(slot, followLinks: false),
        FileSystemEntityType.notFound,
      );
      expect(await File(p.join(target.path, 'php.exe')).exists(), isTrue);
    });
  });
}
