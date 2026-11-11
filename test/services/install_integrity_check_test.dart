import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/services/diagnostics/diagnostic_models.dart';
import 'package:pvm/src/services/diagnostics/doctor_checks.dart';

import '../mocks/mock_os_manager.dart';
import '../support/temp_dir.dart';

void main() {
  late Directory temp;
  late MockOSManager os;

  Future<String> install(String version, {bool verified = true}) async {
    final slot = version.substring(0, version.lastIndexOf('.'));
    final dir = p.join(temp.path, 'versions', slot);
    await File(p.join(dir, 'php.exe')).create(recursive: true);
    await File(p.join(dir, 'php.exe')).writeAsBytes([1, 2, 3]);
    await InstallRecord(
      version: version,
      sourceUrl: 'https://windows.php.net/x.zip',
      archiveSha256: 'abc',
      verified: verified,
      installedAt: DateTime.utc(2026),
      files: await InstallRecord.hashTree(dir),
    ).writeTo(dir);
    os.setDirectoryExistsResult(dir, true);
    return dir;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pvm_integrity_');
    os = MockOSManager()..mockProgramDir = temp.path;
    os.setDirectoryExistsResult(p.join(temp.path, 'versions'), true);
  });

  tearDown(() async => deleteTemp(temp));

  test('intact verified installs are ok', () async {
    await install('8.3.14');
    os.mockVersions = ['8.3'];

    final r = await InstallIntegrityCheck(os).run();

    expect(r.status, DiagnosticStatus.ok);
    expect(r.lines.single, contains('intact'));
  });

  test('a changed php.exe fails and names the file', () async {
    final dir = await install('8.3.14');
    await File(p.join(dir, 'php.exe')).writeAsBytes([6, 6, 6]);
    os.mockVersions = ['8.3'];

    final r = await InstallIntegrityCheck(os).run();

    expect(r.status, DiagnosticStatus.fail);
    expect(r.lines.join('\n'), contains('MODIFIED'));
    expect(r.lines.join('\n'), contains('php.exe'));
  });

  test('unverified source and missing record are warnings', () async {
    await install('8.2.0', verified: false);
    final legacy = p.join(temp.path, 'versions', '8.1');
    await File(p.join(legacy, 'php.exe')).create(recursive: true);
    os.setDirectoryExistsResult(legacy, true);
    os.mockVersions = ['8.2', '8.1'];

    final r = await InstallIntegrityCheck(os).run();

    expect(r.status, DiagnosticStatus.warn);
    expect(r.lines.join('\n'), contains('UNVERIFIED'));
    expect(r.lines.join('\n'), contains('no install record'));
  });

  test('a linked slot reports its record, not "no install record"', () async {
    final target = Directory(p.join(temp.path, 'plesk'))..createSync();
    File(p.join(target.path, 'php.exe')).writeAsBytesSync([1]);
    final versions = p.join(temp.path, 'versions');
    Directory(versions).createSync(recursive: true);
    Link(p.join(versions, '8.4')).createSync(target.path);
    await InstallRecord(
      version: '8.4.15',
      sourceUrl: target.path,
      archiveSha256: '',
      verified: false,
      installedAt: DateTime.utc(2026),
      files: const {},
      kind: SlotKind.linked,
    ).writeToFile(p.join(versions, '8.4.pvm-link.json'));
    os.setDirectoryExistsResult(p.join(versions, '8.4'), true);
    os.mockVersions = ['8.4'];

    final r = await InstallIntegrityCheck(os).run();

    expect(r.lines.join('\n'), isNot(contains('no install record')));
    expect(r.lines.join('\n'), contains('linked to ${target.path}'));
    expect(r.status, DiagnosticStatus.ok);
  });
}
