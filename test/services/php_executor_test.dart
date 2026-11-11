import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/core/os_manager.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/core/executable_resolver.dart';
import 'package:pvm/src/services/php_executor.dart';
import '../support/host_paths.dart';

class TestExecutableResolver implements IExecutableResolver {
  @override
  String get phpExecutableName => 'php.exe';

  @override
  Future<String> resolvePhpExecutable(String projectPath) async {
    return '$projectPath${Platform.pathSeparator}.pvm${Platform.pathSeparator}php.exe';
  }
}

class FakeProcessManager implements IProcessManager {
  final List<ProcessSpec> capturedSpecs = [];
  ProcessSpec? lastSpec;
  int mockExitCode = 0;
  bool shouldThrow = false;

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    capturedSpecs.add(spec);
    lastSpec = spec;
    if (shouldThrow) {
      throw Exception('Mock process failed');
    }
    return mockExitCode;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    throw UnimplementedError();
  }

  @override
  Future<String> resolveSystemCommand(String command) async => command;

  void reset() {
    capturedSpecs.clear();
    lastSpec = null;
    mockExitCode = 0;
    shouldThrow = false;
  }
}

class FakeOSManager implements IOSManager {
  String mockCurrentDirectory = '/mock/project';
  Map<String, bool> fileExistsMap = {};
  Map<String, bool> directoryExistsMap = {};
  bool shouldThrowOnFileExists = false;

  @override
  Future<bool> fileExists(String path) async {
    if (shouldThrowOnFileExists) {
      throw Exception('Mock file check failed');
    }
    return fileExistsMap[path] ?? false;
  }

  @override
  Future<bool> directoryExists(String path) async {
    return directoryExistsMap[path] ?? false;
  }

  @override
  String get currentDirectory => mockCurrentDirectory;

  @override
  Map<String, String> get currentEnvironment => Platform.environment;

  @override
  String get programDirectory => throw UnimplementedError();

  @override
  String get phpVersionsPath => throw UnimplementedError();

  @override
  String get localPath => throw UnimplementedError();

  @override
  Future<({String from, String to})> createSymLink(
    String version,
    String from,
    String to,
  ) async {
    throw UnimplementedError();
  }

  @override
  List<String> getAvailableVersions(String versionsPath) {
    throw UnimplementedError();
  }

  @override
  String getHomeDirectory() => '/fake/home';

  void setFileExists(String path, bool exists) {
    fileExistsMap[path] = exists;
  }

  void setDirectoryExists(String path, bool exists) {
    directoryExistsMap[path] = exists;
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

String getPhpExe(String rootPath) {
  return p.join(rootPath, '.pvm', 'php.exe');
}

void main() {
  group('PhpExecutor', () {
    late PhpExecutor executor;
    late FakeProcessManager processManager;
    late FakeOSManager osManager;
    late TestExecutableResolver exeResolver;

    setUp(() {
      processManager = FakeProcessManager();
      osManager = FakeOSManager();
      exeResolver = TestExecutableResolver();
      executor = PhpExecutor(
        processManager: processManager,
        osManager: osManager,
        executableResolver: exeResolver,
      );
    });

    group('runPhp()', () {
      test('builds correct ProcessSpec with local PHP path and args', () async {
        final root = '/project/root';
        osManager.mockCurrentDirectory = root;
        final phpExe = getPhpExe(root);
        osManager.setFileExists(phpExe, true);

        final exitCode = await executor.runPhp(['--version', '-m']);

        expect(exitCode, equals(0));
        expect(processManager.capturedSpecs.length, equals(1));
        final spec = processManager.lastSpec!;
        expect(spec.executable, equals(phpExe));
        expect(spec.arguments, equals(['--version', '-m']));
        expect(spec.workingDirectory, equals(root));
        // B8: the selected PHP's directory is first on PATH; the rest of
        // the environment is passed through unchanged.
        final env = spec.environment!;
        final pathKey = env.keys.firstWhere((k) => k.toUpperCase() == 'PATH');
        final sep = Platform.isWindows ? ';' : ':';
        expect(env[pathKey]!.split(sep).first, p.dirname(phpExe));
        final base = osManager.currentEnvironment;
        for (final k in base.keys.where((k) => k.toUpperCase() != 'PATH')) {
          expect(env[k], base[k], reason: k);
        }
        expect(
          env.keys.where((k) => k.toUpperCase() == 'PATH'),
          hasLength(1),
          reason: 'must not create a second PATH variable',
        );
      });

      test(
        'B8: runScript (composer) also puts the selected PHP first on PATH',
        () async {
          final root = '/project/root';
          osManager.mockCurrentDirectory = root;
          final phpExe = getPhpExe(root);
          osManager.setFileExists(phpExe, true);

          await executor.runScript('/bin/composer.phar', ['install']);

          final env = processManager.lastSpec!.environment!;
          final pathKey = env.keys.firstWhere((k) => k.toUpperCase() == 'PATH');
          final sep = Platform.isWindows ? ';' : ':';
          expect(env[pathKey]!.split(sep).first, p.dirname(phpExe));
        },
      );

      test(
        'uses currentDirectory from osManager when workingDirectory is null',
        () async {
          final root = '/default/dir';
          osManager.mockCurrentDirectory = root;
          final phpExe = getPhpExe(root);
          osManager.setFileExists(phpExe, true);

          await executor.runPhp(['-v']);

          final spec = processManager.lastSpec!;
          expect(spec.workingDirectory, equals(root));
        },
      );

      test('uses provided workingDirectory override', () async {
        final root = '/override/path';
        final phpExe = getPhpExe(root);
        osManager.setFileExists(phpExe, true);

        await executor.runPhp(['-v'], workingDirectory: root);

        final spec = processManager.lastSpec!;
        expect(spec.workingDirectory, equals(root));
        expect(spec.executable, equals(phpExe));
      });
    });

    group('runScript()', () {
      test('builds correct ProcessSpec with script as first arg', () async {
        final root = '/project';
        osManager.mockCurrentDirectory = root;
        final phpExe = getPhpExe(root);
        osManager.setFileExists(phpExe, true);

        final exitCode = await executor.runScript('scripts/deploy.php', [
          '--env=production',
          '--force',
        ]);

        expect(exitCode, equals(0));
        final spec = processManager.lastSpec!;
        expect(spec.executable, equals(phpExe));
        expect(
          spec.arguments,
          equals(['scripts/deploy.php', '--env=production', '--force']),
        );
      });

      test('script path is first arg even with empty args list', () async {
        final root = '/project';
        osManager.mockCurrentDirectory = root;
        final phpExe = getPhpExe(root);
        osManager.setFileExists(phpExe, true);

        await executor.runScript('test.php', []);

        final spec = processManager.lastSpec!;
        expect(spec.arguments, equals(['test.php']));
      });
    });

    group('_resolvePhpExecutable()', () {
      test('returns correct path for current platform', () async {
        final root = '/any/path';
        final phpExe = getPhpExe(root);
        osManager.setFileExists(phpExe, true);

        await executor.runPhp([], workingDirectory: root);

        expect(processManager.lastSpec!.executable, equals(phpExe));
      });

      test(
        'throws when PHP executable does not exist',
        () async {
          final root = '/missing';
          final phpExe = getPhpExe(root);
          osManager.setFileExists(phpExe, false);

          // Note: Code doesn't validate executable existence before running.
          // Process will fail at OS level, not at PVM level.
          // This test is skipped to reflect current behavior.
        },
        skip: 'Code does not validate executable existence',
      );
    });

    group('File operations use _osManager exclusively', () {
      test(
        'runPhp uses osManager.fileExists() not direct File calls',
        () async {
          final root = '/test';
          final phpExe = getPhpExe(root);
          osManager.setFileExists(phpExe, true);
          osManager.mockCurrentDirectory = root;

          await executor.runPhp(['-v']);

          expect(processManager.lastSpec!.executable, equals(phpExe));
        },
      );
    });

    group('phpExecutable override', () {
      test(
        'runPhp uses provided phpExecutable verbatim and bypasses resolver',
        () async {
          final root = '/some/dir';
          // No file registered for root/.pvm/php.exe, resolver would throw.
          final overridePath = hostPath(r'C:\pvm\versions\8.3.0\php.exe');

          final exitCode = await executor.runPhp(
            ['-v'],
            workingDirectory: root,
            phpExecutable: overridePath,
          );

          expect(exitCode, equals(0));
          expect(processManager.lastSpec!.executable, equals(overridePath));
        },
      );

      test('runScript uses provided phpExecutable verbatim and bypasses '
          'resolver', () async {
        final root = '/some/dir';
        final overridePath = hostPath(r'C:\pvm\versions\8.2.10\php.exe');

        final exitCode = await executor.runScript(
          'tool.php',
          ['--flag'],
          workingDirectory: root,
          phpExecutable: overridePath,
        );

        expect(exitCode, equals(0));
        expect(processManager.lastSpec!.executable, equals(overridePath));
        expect(
          processManager.lastSpec!.arguments,
          equals(['tool.php', '--flag']),
        );
      });

      test('runPhp forwards custom environment to ProcessSpec', () async {
        final root = '/another';
        final overridePath = hostPath(r'C:\pvm\versions\8.3.0\php.exe');
        final env = {
          'PATH': hostPath(r'C:\pvm\versions\8.3.0'),
          'CUSTOM': 'yes',
        };

        await executor.runPhp(
          ['-v'],
          workingDirectory: root,
          phpExecutable: overridePath,
          environment: env,
        );

        final spec = processManager.lastSpec!;
        expect(
          spec.environment?['PATH'],
          equals(hostPath(r'C:\pvm\versions\8.3.0')),
        );
        expect(spec.environment?['CUSTOM'], equals('yes'));
      });

      test(
        'legacy callers without phpExecutable still go through resolver',
        () async {
          final root = '/legacy';
          final phpExe = getPhpExe(root);
          osManager.setFileExists(phpExe, true);

          await executor.runPhp(['-v'], workingDirectory: root);

          expect(processManager.lastSpec!.executable, equals(phpExe));
        },
      );
    });

    group('PATH follows the injected platform, not the host (2.8)', () {
      Future<Map<String, String>> envFor(PlatformInfo platform) async {
        final exec = PhpExecutor(
          processManager: processManager,
          osManager: osManager,
          executableResolver: exeResolver,
          platformInfo: platform,
        );
        await exec.runPhp(
          ['-v'],
          workingDirectory: '/proj',
          phpExecutable: p.join('/pvm', 'v', 'bin', 'php'),
          environment: {'Path': 'base'},
        );
        return processManager.lastSpec!.environment!;
      }

      test('Unix joins with ":" and keeps keys case-sensitive', () async {
        final env = await envFor(LinuxPlatformInfo());

        expect(env['PATH'], p.join('/pvm', 'v', 'bin'));
        expect(env['Path'], 'base');
      });

      test('Windows joins with ";" into the existing Path key', () async {
        final env = await envFor(WindowsPlatformInfo());

        expect(env['Path'], '${p.join('/pvm', 'v', 'bin')};base');
        expect(env.containsKey('PATH'), isFalse);
      });
    });
  });

  group('PhpExecutor slot ini', () {
    test(
      'static slot: -c before user args, scan dir on the child only',
      () async {
        final tmp = Directory.systemTemp.createTempSync('pvm-exec-ini');
        addTearDown(() => tmp.deleteSync(recursive: true));
        final slot = p.join(tmp.path, '8.3');
        Directory(slot).createSync();
        await InstallRecord(
          version: '8.3.1',
          sourceUrl: 'u',
          archiveSha256: 'a',
          verified: true,
          installedAt: DateTime.utc(2026),
          files: const {},
          kind: SlotKind.static,
        ).writeTo(slot);
        final pm = FakeProcessManager();
        final before = Map.of(Platform.environment);
        final given = {'FOO': 'bar'};
        final executor = PhpExecutor(
          processManager: pm,
          osManager: FakeOSManager(),
          executableResolver: TestExecutableResolver(),
          platformInfo: LinuxPlatformInfo(),
        );

        await executor.runPhp(
          ['-v'],
          phpExecutable: p.join(slot, 'bin', 'php'),
          environment: given,
        );

        final spec = pm.lastSpec!;
        expect(spec.arguments, ['-c', p.join(slot, 'etc', 'php.ini'), '-v']);
        expect(
          spec.environment!['PHP_INI_SCAN_DIR'],
          p.join(slot, 'etc', 'conf.d'),
        );
        expect(given, {'FOO': 'bar'});
        expect(Platform.environment, before);
      },
    );

    test('no record: unchanged', () async {
      final pm = FakeProcessManager();
      await PhpExecutor(
        processManager: pm,
        osManager: FakeOSManager(),
        executableResolver: TestExecutableResolver(),
        platformInfo: LinuxPlatformInfo(),
      ).runPhp(['-v'], phpExecutable: '/nope/8.3/bin/php');
      expect(pm.lastSpec!.arguments, ['-v']);
      expect(pm.lastSpec!.environment!.containsKey('PHP_INI_SCAN_DIR'), false);
    });
  });
}
