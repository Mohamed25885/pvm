import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pvm/src/domain/install_record.dart';
import 'package:test/test.dart';

InstallRecord sampleRecord({
  SlotKind kind = SlotKind.static,
  String? phpConfig,
  List<ExtensionEntry> extensions = const [],
}) => InstallRecord(
  version: '8.4.1',
  sourceUrl: 'u',
  archiveSha256: 'a',
  verified: true,
  installedAt: DateTime.utc(2026, 1, 1),
  files: const {'php': 'h'},
  kind: kind,
  zts: true,
  arch: 'arm64',
  apiNo: '20240924',
  phpConfig: phpConfig,
  prefix: '/v/8.4',
  extensionDir: '/v/8.4/ext',
  writable: false,
  vsVersion: 'vs17',
  extensions: extensions,
);

void main() {
  test('v1 record reads as windowsZip with defaults', () {
    final r = InstallRecord.fromJson({
      'schema': 1,
      'version': '8.3.14',
      'sourceUrl': 'u',
      'archiveSha256': 'a',
      'verified': true,
      'installedAt': '2026-01-01T00:00:00.000Z',
      'files': {},
    });
    expect(r.kind, SlotKind.windowsZip);
    expect(r.extensions, isEmpty);
    expect(r.phpConfig, isNull);
    expect(r.arch, 'x64');
    expect(r.writable, isTrue);
  });

  test('v2 round-trips every field', () {
    for (final kind in SlotKind.values) {
      final r = sampleRecord(
        kind: kind,
        phpConfig: '/v/8.4/bin/php-config',
        extensions: [
          ExtensionEntry(
            name: 'xdebug',
            version: '3.5.3',
            file: 'xdebug.so',
            sha256: 'h',
            verified: false,
          ),
        ],
      );
      expect(InstallRecord.fromJson(jsonDecode(jsonEncode(r.toJson()))), r);
    }
  });

  test('kind serialises as static/source/windows-zip/linked', () {
    expect(SlotKind.values.map((k) => sampleRecord(kind: k).toJson()['kind']), [
      'static',
      'source',
      'windows-zip',
      'linked',
    ]);
  });

  test('copyWith replaces only the given fields', () {
    final r = sampleRecord().copyWith(writable: true, extensions: []);
    expect(r.writable, isTrue);
    expect(r.arch, 'arm64');
  });

  test('readFrom defaults extensionDir of a v1 record to <slot>/ext', () async {
    final dir = await Directory.systemTemp.createTemp('pvm-rec-');
    addTearDown(() => dir.delete(recursive: true));
    await File(
      p.join(dir.path, InstallRecord.fileName),
    ).writeAsString(jsonEncode({'schema': 1, 'version': '8.3.14'}));
    final r = (await InstallRecord.readFrom(dir.path))!;
    expect(r.extensionDir, p.join(dir.path, 'ext'));
  });

  test('readFrom treats an empty v2 extensionDir as <slot>/ext', () async {
    final dir = await Directory.systemTemp.createTemp('pvm-rec-');
    addTearDown(() => dir.delete(recursive: true));
    await sampleRecord().copyWith(extensionDir: '').writeTo(dir.path);
    final r = (await InstallRecord.readFrom(dir.path))!;
    expect(r.extensionDir, p.join(dir.path, 'ext'));
  });
}
