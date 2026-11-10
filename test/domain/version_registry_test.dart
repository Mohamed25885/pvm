import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/domain/install_record.dart';

import 'package:pvm/src/domain/version_registry.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/core/os_manager.dart';

/// Test double for IOSManager that provides configurable responses.
class FakeVersionRegistryOSManager implements IOSManager {
  String fakePhpVersionsPath = '/fake/versions';
  Map<String, bool> directoryExistsMap = {};
  List<String> availableVersionsList = [];

  @override
  Future<({String from, String to})> createSymLink(
    String version,
    String from,
    String to,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> directoryExists(String path) async {
    return directoryExistsMap[path] ?? false;
  }

  @override
  Future<bool> fileExists(String path) async {
    return false;
  }

  @override
  List<String> getAvailableVersions(String versionsPath) {
    return availableVersionsList;
  }

  @override
  String get programDirectory => '/fake/pvm';

  @override
  String get phpVersionsPath => fakePhpVersionsPath;

  @override
  String get localPath => '/fake/project/.pvm';

  @override
  String get currentDirectory => '/fake/project';

  @override
  String getHomeDirectory() => '/fake/home';

  @override
  Map<String, String> get currentEnvironment => {};

  void setDirectoryExists(String path, bool exists) {
    directoryExistsMap[path] = exists;
  }

  void setAvailableVersions(List<String> versions) {
    availableVersionsList = versions;
  }

  @override
  Future<bool> isSymLink(String path) async => false;

  @override
  Future<String?> readSymLinkTarget(String path) async => null;

  @override
  Future<void> deleteSymLink(String path) async {}

  @override
  Future<void> deleteDirectory(String path) async {}
}

void main() {
  late VersionRegistry registry;
  late FakeVersionRegistryOSManager osManager;

  setUp(() {
    osManager = FakeVersionRegistryOSManager();
    registry = VersionRegistry(osManager);
  });

  group('VersionRegistry', () {
    group('getInstalledVersions', () {
      test(
        'returns empty list when versions directory does not exist',
        () async {
          osManager.setDirectoryExists('/fake/versions', false);
          osManager.setAvailableVersions([]);

          final versions = await registry.getInstalledVersions();

          expect(versions, isEmpty);
        },
      );

      test('returns empty list when versions directory is empty', () async {
        osManager.setDirectoryExists('/fake/versions', true);
        osManager.setAvailableVersions([]);

        final versions = await registry.getInstalledVersions();

        expect(versions, isEmpty);
      });

      test('returns parsed versions from available versions', () async {
        osManager.setDirectoryExists('/fake/versions', true);
        osManager.setAvailableVersions(['8.2', '8.1', '7.4']);

        final versions = await registry.getInstalledVersions();

        expect(versions.length, 3);
        expect(versions[0].toString(), '8.2');
        expect(versions[1].toString(), '8.1');
        expect(versions[2].toString(), '7.4');
      });

      test('skips invalid version strings', () async {
        osManager.setDirectoryExists('/fake/versions', true);
        osManager.setAvailableVersions([
          '8.2',
          'invalid',
          '7.4',
          'bad-version',
        ]);

        final versions = await registry.getInstalledVersions();

        expect(versions.length, 2);
        expect(versions[0].toString(), '8.2');
        expect(versions[1].toString(), '7.4');
      });

      test('sorts versions newest first', () async {
        osManager.setDirectoryExists('/fake/versions', true);
        osManager.setAvailableVersions(['7.4', '8.2', '8.1', '8.0']);

        final versions = await registry.getInstalledVersions();

        expect(versions.length, 4);
        expect(versions[0].toString(), '8.2');
        expect(versions[1].toString(), '8.1');
        expect(versions[2].toString(), '8.0');
        expect(versions[3].toString(), '7.4');
      });

      test('handles patch versions correctly', () async {
        osManager.setDirectoryExists('/fake/versions', true);
        osManager.setAvailableVersions(['8.2.1', '8.2.0', '8.1.0']);

        final versions = await registry.getInstalledVersions();

        expect(versions.length, 3);
        expect(versions[0].toString(), '8.2.1');
        expect(versions[1].toString(), '8.2.0');
        expect(versions[2].toString(), '8.1.0');
      });
    });

    group('isInstalled', () {
      test('returns true when version directory exists', () async {
        // Use the exact path that will be constructed
        osManager.setDirectoryExists(
          '/fake/versions${Platform.pathSeparator}8.2',
          true,
        );

        final result = await registry.isInstalled(PhpVersion(8, 2));

        expect(result, true);
      });

      test('returns false when version directory does not exist', () async {
        osManager.setDirectoryExists(
          '/fake/versions${Platform.pathSeparator}8.2',
          false,
        );

        final result = await registry.isInstalled(PhpVersion(8, 2));

        expect(result, false);
      });

      test('a patch version checks its minor slot', () async {
        osManager.setDirectoryExists(
          '/fake/versions${Platform.pathSeparator}8.2',
          true,
        );

        final result = await registry.isInstalled(PhpVersion(8, 2, 1));

        expect(result, true);
      });
    });

    group('getVersionPath', () {
      test('returns correct path for version', () {
        final path = registry.getVersionPath(PhpVersion(8, 2));

        expect(path, contains('8.2'));
      });

      test('a patch version maps to its minor slot', () {
        final path = registry.getVersionPath(PhpVersion(8, 2, 1));

        expect(path, p.join('/fake/versions', '8.2'));
      });
    });

    group('installedSlots', () {
      late Directory tmp;

      setUp(() async {
        tmp = await Directory.systemTemp.createTemp('pvm_registry_');
        osManager.fakePhpVersionsPath = tmp.path;
        osManager.setDirectoryExists(tmp.path, true);
      });

      tearDown(() => tmp.delete(recursive: true));

      test(
        'takes the full patch from the record, else the slot name',
        () async {
          final s84 = p.join(tmp.path, '8.4');
          await Directory(s84).create();
          await Directory(p.join(tmp.path, '8.3')).create();
          await InstallRecord(
            version: '8.4.27',
            sourceUrl: '',
            archiveSha256: '',
            verified: true,
            installedAt: DateTime(2026),
            files: const {},
          ).writeTo(s84);
          osManager.setAvailableVersions([
            '8.3',
            '8.4',
            '.staging-8.5',
            '.old-8.4',
            'tmp',
          ]);

          final slots = await registry.installedSlots();

          expect(slots.map((s) => s.version.toString()), ['8.4.27', '8.3']);
          expect(slots.map((s) => s.path), [s84, p.join(tmp.path, '8.3')]);
          expect(slots.first.record?.version, '8.4.27');
          expect(slots.last.record, isNull);
          expect(
            (await registry.getInstalledVersions()).map((v) => v.toString()),
            ['8.4.27', '8.3'],
          );
        },
      );
    });
  });
}
