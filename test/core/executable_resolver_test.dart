import 'dart:io';

import 'package:test/test.dart';

import 'package:pvm/src/core/executable_resolver.dart';
import 'package:pvm/src/core/platform_constants.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/os_manager.dart';

/// Test double for IOSManager.
class FakeExecutableResolverOSManager implements IOSManager {
  Map<String, bool> fileExistsMap = {};

  @override
  Future<({String from, String to})> createSymLink(
      String version, String from, String to) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> directoryExists(String path) async => false;

  @override
  Future<bool> fileExists(String path) async {
    return fileExistsMap[path] ?? false;
  }

  @override
  List<String> getAvailableVersions(String versionsPath) => [];

  @override
  String get programDirectory => '/fake/pvm';

  @override
  String get phpVersionsPath => '/fake/versions';

  @override
  String get localPath => '/fake/project/.pvm';

  @override
  String get currentDirectory => '/fake/project';

  @override
  String getHomeDirectory() => '/fake/home';

  @override
  Map<String, String> get currentEnvironment => {};

  void setFileExists(String path, bool exists) {
    fileExistsMap[path] = exists;
  }
}

void main() {
  late ExecutableResolver resolver;
  late FakeExecutableResolverOSManager osManager;
  late PlatformConstants platformConstants;

  setUp(() {
    osManager = FakeExecutableResolverOSManager();
    platformConstants = PlatformConstants(WindowsPlatformInfo());
    resolver = ExecutableResolver(
      platformConstants: platformConstants,
      osManager: osManager,
    );
  });

  group('ExecutableResolver', () {
    group('phpExecutableName', () {
      test('returns php.exe for Windows', () {
        final winConstants = PlatformConstants(WindowsPlatformInfo());
        final winResolver = ExecutableResolver(
          platformConstants: winConstants,
          osManager: osManager,
        );

        expect(winResolver.phpExecutableName, 'php.exe');
      });

      test('returns php for Linux', () {
        final linuxConstants = PlatformConstants(LinuxPlatformInfo());
        final linuxResolver = ExecutableResolver(
          platformConstants: linuxConstants,
          osManager: osManager,
        );

        expect(linuxResolver.phpExecutableName, 'php');
      });

      test('returns php for macOS', () {
        final macosConstants = PlatformConstants(MacOSPlatformInfo());
        final macosResolver = ExecutableResolver(
          platformConstants: macosConstants,
          osManager: osManager,
        );

        expect(macosResolver.phpExecutableName, 'php');
      });
    });

    group('resolvePhpExecutable', () {
      test('returns path when php.exe exists', () async {
        osManager.setFileExists(
            '/project${Platform.pathSeparator}.pvm${Platform.pathSeparator}php.exe',
            true);

        final result = await resolver.resolvePhpExecutable('/project');

        expect(result, contains('php.exe'));
      });

      test('throws when php.exe does not exist', () async {
        osManager.setFileExists(
            '/project${Platform.pathSeparator}.pvm${Platform.pathSeparator}php.exe',
            false);

        expect(
          () => resolver.resolvePhpExecutable('/project'),
          throwsA(isA<Exception>()),
        );
      });

      test('constructs correct path with pvm dir', () async {
        osManager.setFileExists(
            '/myproject${Platform.pathSeparator}.pvm${Platform.pathSeparator}php.exe',
            true);

        final result = await resolver.resolvePhpExecutable('/myproject');

        expect(result, contains('.pvm'));
        expect(result, contains('php.exe'));
      });
    });
  });
}
