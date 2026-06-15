import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/commands/exec_command.dart';
import 'package:pvm/src/core/active_version_resolver.dart';
import 'package:pvm/src/core/composer_locator.dart';
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/executable_resolver.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/platform_constants.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/core/symlink_inspector.dart';
import 'package:pvm/src/core/os_manager.dart';
import 'package:pvm/src/services/php_executor.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

class _RecordingProcessManager implements IProcessManager {
  ProcessSpec? lastInteractive;
  int exitCode = 0;

  @override
  Future<int> runInteractive(ProcessSpec spec) async {
    lastInteractive = spec;
    return exitCode;
  }

  @override
  Future<CapturedProcessResult> runCaptured(ProcessSpec spec) async {
    throw UnimplementedError();
  }

  @override
  Future<String> resolveSystemCommand(String command) async => command;
}

class _FakePhpExecutor extends PhpExecutor {
  _FakePhpExecutor({
    required IProcessManager processManager,
    required IOSManager osManager,
    required IExecutableResolver executableResolver,
  }) : _processManager = processManager,
       super(
         processManager: processManager,
         osManager: osManager,
         executableResolver: executableResolver,
       );

  final IProcessManager _processManager;

  String? lastPhpExecutable;
  Map<String, String>? lastEnvironment;

  @override
  Future<int> runPhp(
    List<String> args, {
    String? workingDirectory,
    String? phpExecutable,
    Map<String, String>? environment,
  }) async {
    lastPhpExecutable = phpExecutable;
    lastEnvironment = environment;
    return _processManager.runInteractive(
      ProcessSpec(
        executable: phpExecutable ?? 'php',
        arguments: args,
        workingDirectory: workingDirectory,
        environment: environment,
      ),
    );
  }

  @override
  Future<int> runScript(
    String scriptPath,
    List<String> args, {
    String? workingDirectory,
    String? phpExecutable,
    Map<String, String>? environment,
  }) async {
    lastPhpExecutable = phpExecutable;
    lastEnvironment = environment;
    return _processManager.runInteractive(
      ProcessSpec(
        executable: phpExecutable ?? 'php',
        arguments: [scriptPath, ...args],
        workingDirectory: workingDirectory,
        environment: environment,
      ),
    );
  }
}

class _ThrowingResolver implements IExecutableResolver {
  @override
  String get phpExecutableName => 'php.exe';

  @override
  Future<String> resolvePhpExecutable(String projectPath) async {
    throw UnimplementedError();
  }
}

void main() {
  group('ExecCommand', () {
    late MockOSManager osManager;
    late MockConsole console;
    late SymLinkInspector inspector;
    late ActiveVersionResolver resolver;
    late _RecordingProcessManager processManager;
    late _FakePhpExecutor phpExecutor;
    late ComposerLocator composerLocator;

    setUp(() {
      osManager = MockOSManager()
        ..mockHomeDir = r'C:\Users\sam'
        ..mockProgramDir = r'C:\pvm'
        ..mockCurrentDirectory = r'D:\proj'
        ..mockVersions = ['8.3.0'];
      console = MockConsole();
      inspector = SymLinkInspector(osManager);
      resolver = ActiveVersionResolver(inspector);
      processManager = _RecordingProcessManager();

      for (final v in ['8.3.0']) {
        final dir = p.join(r'C:\pvm\versions', v);
        osManager.setDirectoryExistsResult(dir, true);
        osManager.setFileExistsResult(p.join(dir, 'php.exe'), true);
      }
      osManager.setDirectoryExistsResult(r'C:\pvm\versions', true);

      phpExecutor = _FakePhpExecutor(
        processManager: processManager,
        osManager: osManager,
        executableResolver: _ThrowingResolver(),
      );

      composerLocator = ComposerLocator(
        platformConstants: PlatformConstants(WindowsPlatformInfo()),
        osManager: osManager,
      );

      osManager.mockEnvironment = {'PATH': r'C:\bin'};
      osManager.setFileExistsResult(r'C:\bin\composer.phar', true);
    });

    Future<int> runExec(List<String> args) async {
      final runner = CommandRunner<int>('pvm', 'test');
      runner.addCommand(
        ExecCommand(
          osManager: osManager,
          platformConstants: PlatformConstants(WindowsPlatformInfo()),
          phpExecutor: phpExecutor,
          processManager: processManager,
          composerLocator: composerLocator,
          resolver: resolver,
          console: console,
        ),
      );
      return await runner.run(['exec', ...args]) ?? 1;
    }

    test('explicit version + php forwards to runPhp with override', () async {
      final code = await runExec(['8.3.0', 'php', '-v']);

      expect(code, equals(ExitCode.success));
      expect(
        phpExecutor.lastPhpExecutable,
        equals(r'C:\pvm\versions\8.3.0\php.exe'),
      );
      expect(processManager.lastInteractive!.arguments, equals(['-v']));
    });

    test('supports -- separator', () async {
      await runExec(['8.3.0', '--', 'php', '-r', 'echo 1;']);

      expect(
        phpExecutor.lastPhpExecutable,
        equals(r'C:\pvm\versions\8.3.0\php.exe'),
      );
    });

    test('--version flag selects PHP', () async {
      await runExec(['--version', '8.3.0', 'php', '-v']);

      expect(
        phpExecutor.lastPhpExecutable,
        equals(r'C:\pvm\versions\8.3.0\php.exe'),
      );
    });

    test('uses effective version when version omitted', () async {
      final globalLink = p.join(r'C:\Users\sam', PvmConstants.pvmDirName);
      final target = p.join(r'C:\pvm\versions', '8.3.0');
      osManager.symlinkTargets[globalLink] = target;

      await runExec(['php', '-v']);

      expect(
        phpExecutor.lastPhpExecutable,
        equals(r'C:\pvm\versions\8.3.0\php.exe'),
      );
    });

    test('versionNotFound when explicit missing', () async {
      final code = await runExec(['9.0.0', 'php', '-v']);

      expect(code, equals(ExitCode.versionNotFound));
    });

    test('major.minor shorthand resolves when one matching version', () async {
      osManager.mockVersions = ['8.4.1', '8.3.0'];
      for (final v in ['8.4.1', '8.3.0']) {
        final dir = p.join(r'C:\pvm\versions', v);
        osManager.setDirectoryExistsResult(dir, true);
        osManager.setFileExistsResult(p.join(dir, 'php.exe'), true);
      }

      final code = await runExec(['8.4', 'php', '-v']);

      expect(code, ExitCode.success);
      expect(
        phpExecutor.lastPhpExecutable,
        equals(p.join(r'C:\pvm\versions', '8.4.1', 'php.exe')),
      );
    });

    test(
      'major.minor shorthand fails when multiple patches installed',
      () async {
        osManager.mockVersions = ['8.4.0', '8.4.1', '8.3.0'];
        for (final v in ['8.4.0', '8.4.1', '8.3.0']) {
          final dir = p.join(r'C:\pvm\versions', v);
          osManager.setDirectoryExistsResult(dir, true);
          osManager.setFileExistsResult(p.join(dir, 'php.exe'), true);
        }

        final code = await runExec(['8.4', 'php', '-v']);

        expect(code, ExitCode.versionNotFound);
        expect(console.errors.last, contains('ambiguous'));
      },
    );

    test('usage when command empty', () async {
      final code = await runExec(['8.3.0']);

      expect(code, equals(ExitCode.usageError));
    });

    test('generic command prepends phpDir to PATH', () async {
      await runExec(['8.3.0', 'where', 'php']);

      final env = processManager.lastInteractive!.environment!;
      expect(env['PATH']!.startsWith(r'C:\pvm\versions\8.3.0'), isTrue);
      expect(env['PATH']!.contains(r'C:\bin'), isTrue);
    });

    test('composer dispatches through composer locator + runScript', () async {
      await runExec(['8.3.0', 'composer', '--version']);

      expect(
        phpExecutor.lastPhpExecutable,
        equals(r'C:\pvm\versions\8.3.0\php.exe'),
      );
      expect(
        processManager.lastInteractive!.arguments.first,
        equals(r'C:\bin\composer.phar'),
      );
    });
  });
}
