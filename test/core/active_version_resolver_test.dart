import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/active_version_resolver.dart';
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/symlink_inspector.dart';

import '../mocks/mock_os_manager.dart';

void main() {
  group('ActiveVersionResolver.resolve', () {
    late MockOSManager osManager;
    late SymLinkInspector inspector;
    late ActiveVersionResolver resolver;
    const projectRoot = r'D:\projects\demo';

    setUp(() {
      osManager = MockOSManager();
      osManager.mockHomeDir = r'C:\Users\sam';
      osManager.mockProgramDir = r'C:\pvm';
      inspector = SymLinkInspector(osManager);
      resolver = ActiveVersionResolver(inspector);
    });

    String _globalLink() =>
        p.join(osManager.mockHomeDir, PvmConstants.pvmDirName);
    String _localLink() => p.join(projectRoot, PvmConstants.pvmDirName);
    String _versionDir(String version) =>
        p.join(osManager.phpVersionsPath, version);

    test('returns local scope when local is ok (overrides global)', () async {
      final globalTarget = _versionDir('8.2.10');
      osManager.symlinkTargets[_globalLink()] = globalTarget;
      osManager.setDirectoryExistsResult(globalTarget, true);

      final localTarget = _versionDir('8.3.0');
      osManager.symlinkTargets[_localLink()] = localTarget;
      osManager.setDirectoryExistsResult(localTarget, true);

      final active = await resolver.resolve(projectRoot: projectRoot);

      expect(active.scope, equals(VersionScope.local));
      expect(active.version?.toString(), equals('8.3.0'));
      expect(active.global.status, equals(SymLinkStatus.ok));
      expect(active.local.status, equals(SymLinkStatus.ok));
    });

    test('returns global scope when local is notSet', () async {
      final globalTarget = _versionDir('8.2.10');
      osManager.symlinkTargets[_globalLink()] = globalTarget;
      osManager.setDirectoryExistsResult(globalTarget, true);

      final active = await resolver.resolve(projectRoot: projectRoot);

      expect(active.scope, equals(VersionScope.global));
      expect(active.version?.toString(), equals('8.2.10'));
      expect(active.local.status, equals(SymLinkStatus.notSet));
    });

    test('returns global scope when local is broken', () async {
      final globalTarget = _versionDir('8.2.10');
      osManager.symlinkTargets[_globalLink()] = globalTarget;
      osManager.setDirectoryExistsResult(globalTarget, true);

      // local link exists but target missing
      final localTarget = _versionDir('8.4.0');
      osManager.symlinkTargets[_localLink()] = localTarget;
      osManager.setDirectoryExistsResult(localTarget, false);

      final active = await resolver.resolve(projectRoot: projectRoot);

      expect(active.scope, equals(VersionScope.global));
      expect(active.local.status, equals(SymLinkStatus.broken));
    });

    test('returns none when both global and local are missing', () async {
      final active = await resolver.resolve(projectRoot: projectRoot);

      expect(active.scope, equals(VersionScope.none));
      expect(active.version, isNull);
      expect(active.isNone, isTrue);
    });

    test('returns none when global is broken and local is notSet', () async {
      final globalTarget = _versionDir('8.2.10');
      osManager.symlinkTargets[_globalLink()] = globalTarget;
      osManager.setDirectoryExistsResult(globalTarget, false);

      final active = await resolver.resolve(projectRoot: projectRoot);

      expect(active.scope, equals(VersionScope.none));
      expect(active.global.status, equals(SymLinkStatus.broken));
    });
  });
}
