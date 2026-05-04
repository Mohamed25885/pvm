import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/managers/windows_version_activator.dart';

import '../mocks/mock_os_manager.dart';

void main() {
  group('WindowsVersionActivator', () {
    late MockOSManager osManager;

    setUp(() {
      osManager = MockOSManager();
      osManager.symlinkSourceExistsOverride = true;
    });

    group('activateGlobal', () {
      test('creates symlink at <home>/.pvm pointing to versionsPath/<version>',
          () async {
        final activator = WindowsVersionActivator(
          osManager: osManager,
          versionsPath: r'C:\pvm\versions',
          homeDirectory: r'C:\Users\sam',
        );

        await activator.activateGlobal('8.2.10');

        expect(osManager.createdSymlinks, hasLength(1));
        final call = osManager.createdSymlinks.single;
        expect(call.version, equals('8.2.10'));
        expect(call.from, equals(p.join(r'C:\pvm\versions', '8.2.10')));
        expect(
            call.to, equals(p.join(r'C:\Users\sam', PvmConstants.pvmDirName)));
      });

      test('forwards version string verbatim (does not mutate)', () async {
        final activator = WindowsVersionActivator(
          osManager: osManager,
          versionsPath: r'C:\pvm\versions',
          homeDirectory: r'C:\Users\sam',
        );

        await activator.activateGlobal('7.4');

        expect(osManager.createdSymlinks.single.version, equals('7.4'));
      });

      test('propagates exception from OSManager.createSymLink', () async {
        osManager.shouldThrowOnSymlink = true;
        osManager.symlinkErrorMessage = 'Permission denied';

        final activator = WindowsVersionActivator(
          osManager: osManager,
          versionsPath: r'C:\pvm\versions',
          homeDirectory: r'C:\Users\sam',
        );

        await expectLater(
          activator.activateGlobal('8.2'),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('Permission denied'))),
        );
      });
    });

    group('activateLocal', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('pvm_activator_local_');
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test(
          'creates symlink at <projectRoot>/.pvm when .php-version found in cwd',
          () async {
        final phpVersion =
            File(p.join(tempDir.path, PvmConstants.phpVersionFileName));
        await phpVersion.writeAsString('8.2');

        osManager.mockCurrentDirectory = tempDir.path;

        final activator = WindowsVersionActivator(
          osManager: osManager,
          versionsPath: r'C:\pvm\versions',
          homeDirectory: r'C:\Users\sam',
        );

        await activator.activateLocal('8.2');

        expect(osManager.createdSymlinks, hasLength(1));
        final call = osManager.createdSymlinks.single;
        expect(call.from, equals(p.join(r'C:\pvm\versions', '8.2')));
        expect(call.to, equals(p.join(tempDir.path, PvmConstants.pvmDirName)));
      });

      test('walks up to ancestor directory containing .php-version', () async {
        final phpVersion =
            File(p.join(tempDir.path, PvmConstants.phpVersionFileName));
        await phpVersion.writeAsString('8.2');

        final nested = Directory(p.join(tempDir.path, 'a', 'b'));
        await nested.create(recursive: true);
        osManager.mockCurrentDirectory = nested.path;

        final activator = WindowsVersionActivator(
          osManager: osManager,
          versionsPath: r'C:\pvm\versions',
          homeDirectory: r'C:\Users\sam',
        );

        await activator.activateLocal('8.2');

        final call = osManager.createdSymlinks.single;
        expect(call.to, equals(p.join(tempDir.path, PvmConstants.pvmDirName)));
      });

      test('falls back to current directory when no .php-version found',
          () async {
        osManager.mockCurrentDirectory = tempDir.path;

        final activator = WindowsVersionActivator(
          osManager: osManager,
          versionsPath: r'C:\pvm\versions',
          homeDirectory: r'C:\Users\sam',
        );

        await activator.activateLocal('8.2');

        final call = osManager.createdSymlinks.single;
        expect(call.to, equals(p.join(tempDir.path, PvmConstants.pvmDirName)));
      });
    });
  });
}
