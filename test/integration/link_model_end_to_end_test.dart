import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pvm/src/core/active_version_resolver.dart';
import 'package:pvm/src/core/executable_resolver.dart';
import 'package:pvm/src/core/link_manager.dart';
import 'package:pvm/src/core/platform_constants.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/symlink_inspector.dart';
import 'package:pvm/src/managers/io_os_manager.dart';
import 'package:pvm/src/managers/link_version_activator.dart';
import 'package:test/test.dart';

/// B16 regression on the real OS layer of whichever OS runs it (junction on
/// Windows, symlink on Linux/macOS): activate, then every reader agrees the
/// link is healthy and finds PHP through it.
void main() {
  test('activate -> inspect -> resolve agree on every OS (B16)', () async {
    final temp = await Directory.systemTemp.createTemp('pvm_e2e_link_');
    final home = await Directory(p.join(temp.path, 'home')).create();
    final project = await Directory(p.join(temp.path, 'project')).create();
    final versions = p.join(temp.path, 'versions');
    final platform = createPlatformInfo();
    final constants = PlatformConstants(platform);
    final binary = constants.phpLayout.phpExecutable(p.join(versions, '8.3.1'));
    await File(binary).create(recursive: true);

    final os = IoOSManager(
      platformInfo: platform,
      linkManager: createLinkManager(platform),
      environment: {
        'PVM_VERSIONS_HOME': versions,
        'HOME': home.path,
        'USERPROFILE': home.path,
      },
    );
    final link = p.join(home.path, '.pvm');
    addTearDown(() async {
      await os.deleteSymLink(link);
      await temp.delete(recursive: true);
    });

    await LinkVersionActivator(
      osManager: os,
      versionsPath: versions,
      homeDirectory: home.path,
    ).activateGlobal('8.3.1');

    final info = await SymLinkInspector(os).inspectGlobal();
    expect(info.status, SymLinkStatus.ok, reason: '$info');
    expect(info.version.toString(), '8.3.1');

    final active = await ActiveVersionResolver(
      SymLinkInspector(os),
    ).resolve(projectRoot: project.path);
    expect(active.scope, VersionScope.global);

    final php = await ExecutableResolver(
      platformConstants: constants,
      osManager: os,
    ).resolvePhpExecutable(home.path);
    expect(php, constants.phpLayout.phpExecutable(link));
    expect(await File(php).exists(), isTrue);
  });
}
