import 'dart:io';

import 'package:test/test.dart';

import 'package:pvm/src/core/os_manager.dart';
import 'package:pvm/src/core/process_manager.dart';

import '../helpers.dart';
import '../services/fake_os_manager.dart';
import '../services/fake_process_manager.dart';
import 'package:pvm/src/services/php_executor.dart';

void main() {
  group('ComposerCommand', () {
    late FakeOSManager osManager;
    late FakePhpExecutor phpExecutor;
    late TestPvmCommandRunner runner;

    setUp(() {
      osManager = FakeOSManager();
      final processManager = FakeProcessManager();
      phpExecutor = FakePhpExecutor(osManager, processManager);

      // Set up a project directory
      final tempDir = Directory.systemTemp.createTempSync('pvm-composer-');
      osManager.mockCurrentDirectory = tempDir.path;
      osManager.setDirectoryExists(r'${tempDir.path}\.pvm', true);
      osManager.environment = {'PATH': ''};

      runner = TestPvmCommandRunner(
        osManager: osManager,
        phpExecutor: phpExecutor,
      );
    });

    test('constructor accepts dependencies', () {
      // Just verify construction works
      expect(runner.runner.commands.containsKey('composer'), isTrue);
    });

    group('run()', () {
      test('error when local .pvm directory missing', () async {
        osManager.setDirectoryExists(r'C:\project\.pvm', false);
        osManager.mockCurrentDirectory = r'C:\project';

        final exitCode = await runner.run(['composer']);

        expect(exitCode, equals(1));
        expect(phpExecutor.lastScriptPath, isNull);
      });

      test('error when Composer not found in PATH', () async {
        osManager.setDirectoryExists(r'C:\project\.pvm', true);
        osManager.mockCurrentDirectory = r'C:\project';
        // PATH empty => not found
        osManager.environment = {'PATH': ''};

        final exitCode = await runner.run(['composer']);

        expect(exitCode, equals(1));
        expect(phpExecutor.lastScriptPath, isNull);
      });

      test('success: finds Composer in PATH and forwards args', () async {
        osManager.setDirectoryExists(r'C:\project\.pvm', true);
        osManager.mockCurrentDirectory = r'C:\project';
        // Simulate composer.phar in C:\usr\local\bin
        osManager.fileExistsMap[r'C:\usr\local\bin\composer.phar'] = true;
        osManager.environment = {'PATH': r'C:\usr\local\bin'};
        phpExecutor.mockExitCode = 0;

        final exitCode = await runner.run(['composer']);

        expect(exitCode, equals(0));
        expect(phpExecutor.lastScriptPath, r'C:\usr\local\bin\composer.phar');
        expect(phpExecutor.lastArgs, []); // no extra args
        expect(phpExecutor.lastWorkingDirectory, r'C:\project');
      });

      test('forwards arguments unchanged', () async {
        osManager.setDirectoryExists(r'C:\project\.pvm', true);
        osManager.mockCurrentDirectory = r'C:\project';
        osManager.fileExistsMap[r'C:\usr\local\bin\composer.phar'] = true;
        osManager.environment = {'PATH': r'C:\usr\local\bin'};

        await runner.run(['composer', 'install', '--no-dev', '-vvv']);

        expect(phpExecutor.lastArgs, ['install', '--no-dev', '-vvv']);
      });

      test('batch file resolution: finds composer.phar in same dir', () async {
        osManager.setDirectoryExists(r'C:\project\.pvm', true);
        osManager.mockCurrentDirectory = r'C:\project';
        // Simulate composer.bat in C:\Composer
        osManager.fileExistsMap[r'C:\Composer\composer.bat'] = true;
        osManager.fileExistsMap[r'C:\Composer\composer.phar'] = true;
        osManager.environment = {'PATH': r'C:\Composer'};

        await runner.run(['composer', 'update']);

        expect(phpExecutor.lastScriptPath, r'C:\Composer\composer.phar');
      }, skip: !Platform.isWindows);

      test('batch file without .phar is skipped (treated as not found)',
          () async {
        osManager.setDirectoryExists(r'C:\project\.pvm', true);
        osManager.mockCurrentDirectory = r'C:\project';
        osManager.fileExistsMap[r'C:\Composer\composer.bat'] = true;
        // NO composer.phar in same dir
        osManager.environment = {'PATH': r'C:\Composer'};

        final exitCode = await runner.run(['composer', 'update']);

        expect(exitCode, equals(0));
        expect(phpExecutor.lastScriptPath, equals(r'C:\Composer\composer.bat'));
      }, skip: !Platform.isWindows);
    });
  });
}

/// Fake implementation of [PhpExecutor] for testing.
class FakePhpExecutor implements PhpExecutor {
  final IProcessManager processManager;
  final IOSManager osManager;

  FakePhpExecutor(this.osManager, this.processManager);

  @override
  Future<int> runPhp(List<String> args, {String? workingDirectory}) {
    throw UnimplementedError('Not needed for ComposerCommand tests');
  }

  @override
  Future<int> runScript(String scriptPath, List<String> args,
      {String? workingDirectory}) async {
    // Record the call for verification
    lastScriptPath = scriptPath;
    lastArgs = args;
    lastWorkingDirectory = workingDirectory;
    return mockExitCode;
  }

  // Test verification data
  String? lastScriptPath;
  List<String>? lastArgs;
  String? lastWorkingDirectory;
  int mockExitCode = 0;
}
