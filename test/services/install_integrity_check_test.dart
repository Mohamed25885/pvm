import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/services/diagnostics/diagnostic_models.dart';
import 'package:pvm/src/services/diagnostics/doctor_checks.dart';

import '../mocks/mock_os_manager.dart';

void main() {
  late Directory temp;
  late MockOSManager os;

  Future<String> install(String version, {bool verified = true}) async {
    final dir = p.join(temp.path, 'versions', version);
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

  tearDown(() async => temp.delete(recursive: true));

  test('intact verified installs are ok', () async {
    await install('8.3.14');
    os.mockVersions = ['8.3.14'];

    final r = await InstallIntegrityCheck(os).run();

    expect(r.status, DiagnosticStatus.ok);
    expect(r.lines.single, contains('intact'));
  });

  test('a changed php.exe fails and names the file', () async {
    final dir = await install('8.3.14');
    await File(p.join(dir, 'php.exe')).writeAsBytes([6, 6, 6]);
    os.mockVersions = ['8.3.14'];

    final r = await InstallIntegrityCheck(os).run();

    expect(r.status, DiagnosticStatus.fail);
    expect(r.lines.join('\n'), contains('MODIFIED'));
    expect(r.lines.join('\n'), contains('php.exe'));
  });

  test('unverified source and missing record are warnings', () async {
    await install('8.2.0', verified: false);
    final legacy = p.join(temp.path, 'versions', '8.1.0');
    await File(p.join(legacy, 'php.exe')).create(recursive: true);
    os.setDirectoryExistsResult(legacy, true);
    os.mockVersions = ['8.2.0', '8.1.0'];

    final r = await InstallIntegrityCheck(os).run();

    expect(r.status, DiagnosticStatus.warn);
    expect(r.lines.join('\n'), contains('UNVERIFIED'));
    expect(r.lines.join('\n'), contains('no install record'));
  });
}
