import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/symlink_inspector.dart';

import '../mocks/mock_os_manager.dart';

void main() {
  group('SymLinkInspector.inspect', () {
    late MockOSManager osManager;
    late SymLinkInspector inspector;
    const versionsRoot = r'C:\pvm\versions';

    setUp(() {
      osManager = MockOSManager();
      inspector = SymLinkInspector(osManager);
    });

    test('returns notSet when nothing exists at linkPath', () async {
      const linkPath = r'C:\Users\sam\.pvm';
      final info = await inspector.inspect(
        linkPath: linkPath,
        versionsRoot: versionsRoot,
      );

      expect(info.linkPath, equals(linkPath));
      expect(info.status, equals(SymLinkStatus.notSet));
      expect(info.target, isNull);
      expect(info.version, isNull);
    });

    test('returns ok when symlink points to a valid version directory',
        () async {
      const linkPath = r'C:\Users\sam\.pvm';
      final target = p.join(versionsRoot, '8.2.10');
      osManager.symlinkTargets[linkPath] = target;
      osManager.setDirectoryExistsResult(target, true);

      final info = await inspector.inspect(
        linkPath: linkPath,
        versionsRoot: versionsRoot,
      );

      expect(info.status, equals(SymLinkStatus.ok));
      expect(info.target, equals(target));
      expect(info.version?.toString(), equals('8.2.10'));
      expect(info.isOk, isTrue);
    });

    test('returns broken when symlink exists but target dir is missing',
        () async {
      const linkPath = r'C:\Users\sam\.pvm';
      final target = p.join(versionsRoot, '8.2.10');
      osManager.symlinkTargets[linkPath] = target;
      osManager.setDirectoryExistsResult(target, false);

      final info = await inspector.inspect(
        linkPath: linkPath,
        versionsRoot: versionsRoot,
      );

      expect(info.status, equals(SymLinkStatus.broken));
      expect(info.target, equals(target));
      expect(info.version, isNull);
    });

    test('returns orphaned when target lives outside versions root', () async {
      const linkPath = r'C:\Users\sam\.pvm';
      const target = r'C:\custom\php-installs\8.2.10';
      osManager.symlinkTargets[linkPath] = target;
      osManager.setDirectoryExistsResult(target, true);

      final info = await inspector.inspect(
        linkPath: linkPath,
        versionsRoot: versionsRoot,
      );

      expect(info.status, equals(SymLinkStatus.orphaned));
      expect(info.target, equals(target));
    });

    test(
        'returns orphaned when target is inside versionsRoot but basename is '
        'not a valid version', () async {
      const linkPath = r'C:\Users\sam\.pvm';
      final target = p.join(versionsRoot, 'weird-name');
      osManager.symlinkTargets[linkPath] = target;
      osManager.setDirectoryExistsResult(target, true);

      final info = await inspector.inspect(
        linkPath: linkPath,
        versionsRoot: versionsRoot,
      );

      expect(info.status, equals(SymLinkStatus.orphaned));
      expect(info.version, isNull);
    });

    test('returns corrupt when slot exists as a non-symlink directory',
        () async {
      const linkPath = r'C:\Users\sam\.pvm';
      osManager.setDirectoryExistsResult(linkPath, true);

      final info = await inspector.inspect(
        linkPath: linkPath,
        versionsRoot: versionsRoot,
      );

      expect(info.status, equals(SymLinkStatus.corrupt));
    });

    test('returns corrupt when slot exists as a non-symlink file', () async {
      const linkPath = r'C:\Users\sam\.pvm';
      osManager.setFileExistsResult(linkPath, true);

      final info = await inspector.inspect(
        linkPath: linkPath,
        versionsRoot: versionsRoot,
      );

      expect(info.status, equals(SymLinkStatus.corrupt));
    });
  });

  group('SymLinkInspector convenience methods', () {
    late MockOSManager osManager;
    late SymLinkInspector inspector;

    setUp(() {
      osManager = MockOSManager();
      osManager.mockHomeDir = r'C:\Users\sam';
      osManager.mockProgramDir = r'C:\pvm';
      inspector = SymLinkInspector(osManager);
    });

    test('inspectGlobal uses home/.pvm and phpVersionsPath', () async {
      final globalLink = p.join(r'C:\Users\sam', PvmConstants.pvmDirName);
      final target = p.join(osManager.phpVersionsPath, '8.3.0');
      osManager.symlinkTargets[globalLink] = target;
      osManager.setDirectoryExistsResult(target, true);

      final info = await inspector.inspectGlobal();

      expect(info.status, equals(SymLinkStatus.ok));
      expect(info.linkPath, equals(globalLink));
    });

    test('inspectLocal joins projectRoot with .pvm', () async {
      const projectRoot = r'D:\projects\demo';
      final localLink = p.join(projectRoot, PvmConstants.pvmDirName);
      final target = p.join(osManager.phpVersionsPath, '8.2.10');
      osManager.symlinkTargets[localLink] = target;
      osManager.setDirectoryExistsResult(target, true);

      final info = await inspector.inspectLocal(projectRoot);

      expect(info.status, equals(SymLinkStatus.ok));
      expect(info.linkPath, equals(localLink));
    });
  });
}
