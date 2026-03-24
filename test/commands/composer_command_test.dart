import 'dart:io';

import 'package:test/test.dart';
import 'package:pvm/src/commands/composer_command.dart';
import 'package:pvm/src/core/os_manager.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/services/php_executor.dart';

import '../services/fake_os_manager.dart';
import '../services/fake_process_manager.dart';

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

void main() {
  group('ComposerCommand', () {
    late FakeOSManager osManager;
    late FakePhpExecutor phpExecutor;
    late ComposerCommand command;

    setUp(() {
      osManager = FakeOSManager();
      phpExecutor = FakePhpExecutor(osManager, FakeProcessManager());
      command = ComposerCommand(osManager, phpExecutor);
    });

    test('constructor accepts dependencies', () {
      // Just verify construction works
      expect(command.name, 'composer');
    });

    group('run()', () {
      test('error when local .pvm directory missing', () async {
        // .pvm does not exist
        osManager.setDirectoryExists(r'C:\project\.pvm', false);
        osManager.mockCurrentDirectory = r'C:\project';

        final exitCode = await command.run();

        expect(exitCode, equals(1));
        expect(phpExecutor.lastScriptPath, isNull);
      });

      test('error when Composer not found in PATH', () async {
        osManager.setDirectoryExists(r'C:\project\.pvm', true);
        osManager.mockCurrentDirectory = r'C:\project';
        // PATH empty => not found
        osManager.environment = {'PATH': ''};

        final exitCode = await command.run();

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

        final exitCode = await command.run();

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

        await command.runWithArgs(['install', '--no-dev', '-vvv']);

        expect(phpExecutor.lastArgs, ['install', '--no-dev', '-vvv']);
      });

      test('batch file resolution: finds composer.phar in same dir', () async {
        osManager.setDirectoryExists(r'C:\project\.pvm', true);
        osManager.mockCurrentDirectory = r'C:\project';
        // Simulate composer.bat in C:\Composer
        osManager.fileExistsMap[r'C:\Composer\composer.bat'] = true;
        osManager.fileExistsMap[r'C:\Composer\composer.phar'] = true;
        osManager.environment = {'PATH': r'C:\Composer'};

        await command.runWithArgs(['update']);

        expect(phpExecutor.lastScriptPath, r'C:\Composer\composer.phar');
      }, skip: !Platform.isWindows);

      test('batch file without .phar is skipped (treated as not found)',
          () async {
        osManager.setDirectoryExists(r'C:\project\.pvm', true);
        osManager.mockCurrentDirectory = r'C:\project';
        osManager.fileExistsMap[r'C:\Composer\composer.bat'] = true;
        // NO composer.phar in same dir
        osManager.environment = {'PATH': r'C:\Composer'};

        final exitCode = await command.runWithArgs(['update']);

        expect(exitCode, equals(1));
        expect(phpExecutor.lastScriptPath, isNull);
      }, skip: !Platform.isWindows);
    });
  });
}
