import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/active_version_resolver.dart';
import '../core/composer_locator.dart';
import '../core/console.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../core/platform_constants.dart';
import '../core/process_manager.dart';
import '../domain/exceptions.dart';
import '../domain/php_version.dart';
import '../domain/project.dart';
import '../domain/version_diagnostics.dart';
import '../domain/version_registry.dart';
import '../services/php_executor.dart';

/// `pvm exec` — run a command with a specific PHP installation on `PATH`.
class ExecCommand extends Command<int> {
  @override
  final String name = 'exec';

  @override
  final String description =
      'Run a command using a specific installed PHP version';

  @override
  final ArgParser argParser = ArgParser.allowAnything();

  final IOSManager _osManager;
  final PlatformConstants _platformConstants;
  final PhpExecutor _phpExecutor;
  final IProcessManager _processManager;
  final IComposerLocator _composerLocator;
  final ActiveVersionResolver _resolver;
  final Console _console;

  ExecCommand({
    required IOSManager osManager,
    required PlatformConstants platformConstants,
    required PhpExecutor phpExecutor,
    required IProcessManager processManager,
    required IComposerLocator composerLocator,
    required ActiveVersionResolver resolver,
    required Console console,
  })  : _osManager = osManager,
        _platformConstants = platformConstants,
        _phpExecutor = phpExecutor,
        _processManager = processManager,
        _composerLocator = composerLocator,
        _resolver = resolver,
        _console = console;

  @override
  Future<int> run() async {
    final raw = List<String>.from(argResults!.rest);
    final parsed = _parseLeadingFlags(raw);

    var tokens = List<String>.from(parsed.command);
    if (tokens.isEmpty) {
      _console.printError('No command specified.');
      _console.print('Usage: pvm exec [version] [--] <command> [args...]\n'
          '   or: pvm exec --version <ver> [--] <command> [args...]');
      return ExitCode.usageError;
    }

    final workDir = parsed.cwd ?? _osManager.currentDirectory;
    final project = await Project.findFromPath(workDir);

    final registry = VersionRegistry(_osManager);
    final installed = await registry.getInstalledVersions();

    late final PhpVersion version;
    if (parsed.versionFromFlag != null) {
      try {
        final parsedVer = PhpVersion.parse(parsed.versionFromFlag!);
        final resolved = _resolveFromInstalled(parsedVer, installed);
        if (resolved == null || !await registry.isInstalled(resolved)) {
          _console.printError(VersionDiagnostics.notInstalledMessage(
            requested: parsedVer,
            installed: installed,
          ));
          return ExitCode.versionNotFound;
        }
        version = resolved;
      } on InvalidVersionFormatException catch (e) {
        _console.printError(e.message);
        return ExitCode.usageError;
      }
    } else {
      PhpVersion? maybeVersionToken;
      try {
        maybeVersionToken = PhpVersion.parse(tokens.first);
      } on InvalidVersionFormatException {
        maybeVersionToken = null;
      }

      if (maybeVersionToken != null) {
        final resolved = _resolveFromInstalled(maybeVersionToken, installed);
        if (resolved == null || !await registry.isInstalled(resolved)) {
          _console.printError(VersionDiagnostics.notInstalledMessage(
            requested: maybeVersionToken,
            installed: installed,
          ));
          return ExitCode.versionNotFound;
        }
        version = resolved;
        tokens = tokens.sublist(1);
      } else {
        final active =
            await _resolver.resolve(projectRoot: project.rootDirectory.path);
        if (active.version == null) {
          _console.printError(
            'No active PHP version. Run `pvm global <version>` first, '
            'or pass an explicit version.',
          );
          return ExitCode.configurationError;
        }
        version = active.version!;
      }
    }

    while (tokens.isNotEmpty && tokens.first == '--') {
      tokens = tokens.sublist(1);
    }

    if (tokens.isEmpty) {
      _console.printError('No command specified.');
      return ExitCode.usageError;
    }

    final phpDir = p.join(_osManager.phpVersionsPath, version.toString());
    final phpExe = p.join(phpDir, _platformConstants.phpExecutableName);

    if (!await _osManager.fileExists(phpExe)) {
      _console.printError(
        'PHP executable missing for $version at:\n  $phpExe',
      );
      return ExitCode.generalError;
    }

    final cmd0 = tokens.first;
    final cmdRest = tokens.sublist(1);

    if (_isPhpCommand(cmd0)) {
      return _phpExecutor.runPhp(
        cmdRest,
        workingDirectory: workDir,
        phpExecutable: phpExe,
      );
    }

    if (_isComposerCommand(cmd0)) {
      final script = await _composerLocator.findComposer(
        _osManager.currentEnvironment,
      );
      if (script == null) {
        _console.printError(
          'Composer not found in PATH.\n'
          'Install Composer globally or ensure composer.phar is on PATH.',
        );
        return ExitCode.generalError;
      }
      return _phpExecutor.runScript(
        script,
        cmdRest,
        workingDirectory: workDir,
        phpExecutable: phpExe,
      );
    }

    final env = Map<String, String>.from(_osManager.currentEnvironment);
    final sep = _platformConstants.pathSeparator;
    final oldPath = env['PATH'] ?? '';
    env['PATH'] = oldPath.isEmpty ? phpDir : '$phpDir$sep$oldPath';

    try {
      final resolvedExe = await _processManager.resolveSystemCommand(cmd0);
      return _processManager.runInteractive(
        ProcessSpec(
          executable: resolvedExe,
          arguments: cmdRest,
          workingDirectory: workDir,
          environment: env,
        ),
      );
    } on Exception catch (e) {
      _console.printError('Could not start "$cmd0": $e');
      return ExitCode.generalError;
    }
  }

  bool _isPhpCommand(String cmd) {
    final base = p.basename(cmd).toLowerCase();
    return base == 'php' ||
        base == 'php.exe' ||
        base == _platformConstants.phpExecutableName.toLowerCase();
  }

  bool _isComposerCommand(String cmd) {
    final base = p.basename(cmd).toLowerCase();
    if (base == 'composer') return true;
    return _platformConstants.composerCandidates
        .map((c) => c.toLowerCase())
        .contains(base);
  }

  _ParsedExecFlags _parseLeadingFlags(List<String> input) {
    String? versionFlag;
    String? cwdFlag;
    var i = 0;
    while (i < input.length) {
      final t = input[i];
      if (t == '--version' && i + 1 < input.length) {
        versionFlag = input[i + 1];
        i += 2;
        continue;
      }
      if (t.startsWith('--version=')) {
        versionFlag = t.substring('--version='.length);
        i++;
        continue;
      }
      if (t == '--cwd' && i + 1 < input.length) {
        cwdFlag = input[i + 1];
        i += 2;
        continue;
      }
      if (t.startsWith('--cwd=')) {
        cwdFlag = t.substring('--cwd='.length);
        i++;
        continue;
      }
      break;
    }
    return _ParsedExecFlags(
      versionFromFlag: versionFlag,
      cwd: cwdFlag,
      command: input.sublist(i),
    );
  }

  PhpVersion? _resolveFromInstalled(
    PhpVersion parsed,
    List<PhpVersion> installed,
  ) {
    if (installed.contains(parsed)) return parsed;
    if (parsed.hasPatch) return null;

    final candidates = installed
        .where((v) => v.major == parsed.major && v.minor == parsed.minor)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.compareTo(a));
    return candidates.first;
  }
}

class _ParsedExecFlags {
  final String? versionFromFlag;
  final String? cwd;
  final List<String> command;

  _ParsedExecFlags({
    required this.versionFromFlag,
    required this.cwd,
    required this.command,
  });
}
