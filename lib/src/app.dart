import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'commands/composer_command.dart';
import 'commands/current_command.dart';
import 'commands/doctor_command.dart';
import 'commands/exec_command.dart';
import 'commands/global_command.dart';
import 'commands/install_command.dart';
import 'commands/list_command.dart';
import 'commands/list_remote_command.dart';
import 'commands/php_command.dart';
import 'commands/setup_command.dart';
import 'commands/uninstall_command.dart';
import 'commands/use_command.dart';
import 'commands/version_flag.dart';
import 'console/console_io.dart';
import 'core/active_version_resolver.dart';
import 'core/composer_locator.dart';
import 'core/console.dart';
import 'core/elevating_os_manager.dart';
import 'core/environment_configurator_factory.dart';
import 'core/error_text.dart';
import 'core/executable_resolver.dart';
import 'core/exit_codes.dart';
import 'core/gitignore_service.dart';
import 'core/os_manager.dart';
import 'core/os_manager_factory.dart';
import 'core/php_version_manager.dart';
import 'core/platform_constants.dart';
import 'core/platform_info.dart';
import 'core/privilege_escalator_factory.dart';
import 'core/process_manager.dart';
import 'core/symlink_inspector.dart';
import 'interfaces/i_environment_configurator.dart';
import 'interfaces/i_installer.dart';
import 'interfaces/i_version_activator.dart';
import 'managers/link_version_activator.dart';
import 'managers/linux_installer.dart';
import 'managers/macos_installer.dart';
import 'managers/windows_installer.dart';
import 'process/io_process_manager.dart';
import 'services/php_executor.dart';
import 'services/privilege_escalation_service.dart';
import 'services/release_fetcher.dart';
import 'services/release_fetcher_factory.dart';
import 'services/windows_archive_index.dart';
import 'version.dart';

class PvmCommandRunner extends CommandRunner<int> {
  PvmCommandRunner(super.executableName, super.description);

  ArgParser? _parser;
  @override
  ArgParser get argParser => _parser ??= ArgParser(allowTrailingOptions: true);
}

/// Everything the commands need, built once. The only place that picks
/// platform implementations (roadmap 2.7); tests pass their own pieces.
class PvmDependencies {
  final PlatformInfo platform;
  final Console console;
  final IOSManager osManager;
  final IProcessManager processManager;
  final IReleaseFetcher releaseFetcher;
  final IInstaller installer;
  final IVersionActivator versionActivator;
  final IEnvironmentConfigurator environmentConfigurator;

  const PvmDependencies({
    required this.platform,
    required this.console,
    required this.osManager,
    required this.processManager,
    required this.releaseFetcher,
    required this.installer,
    required this.versionActivator,
    required this.environmentConfigurator,
  });

  /// The real implementations for [platform] (default: the host). Any
  /// argument given replaces the real one.
  factory PvmDependencies.forHost({
    PlatformInfo? platform,
    Console? console,
    IOSManager? osManager,
    IProcessManager? processManager,
    IReleaseFetcher? releaseFetcher,
    IInstaller? installer,
    IVersionActivator? versionActivator,
    IEnvironmentConfigurator? environmentConfigurator,
  }) {
    final host = platform ?? createPlatformInfo();
    final io = console ?? ConsoleIO();
    final os =
        osManager ??
        ElevatingOSManager(
          createBaseOSManager(host),
          PrivilegeEscalationService(io, createPrivilegeEscalator(host)),
        );
    final processes =
        processManager ?? IOProcessManager(osManager: os, platformInfo: host);
    final fetcher = releaseFetcher ?? createReleaseFetcher(host);

    return PvmDependencies(
      platform: host,
      console: io,
      osManager: os,
      processManager: processes,
      releaseFetcher: fetcher,
      installer:
          installer ?? _createInstaller(host, os, processes, fetcher, io),
      versionActivator:
          versionActivator ??
          LinkVersionActivator(
            osManager: os,
            versionsPath: os.phpVersionsPath,
            homeDirectory: os.getHomeDirectory(),
          ),
      environmentConfigurator:
          environmentConfigurator ?? createEnvironmentConfigurator(host),
    );
  }

  static IInstaller _createInstaller(
    PlatformInfo platform,
    IOSManager os,
    IProcessManager processes,
    IReleaseFetcher fetcher,
    Console console,
  ) {
    final versionsPath = os.phpVersionsPath;
    switch (platform.osType) {
      case 'windows':
        return WindowsInstaller(
          versionsPath: versionsPath,
          releaseFetcher: fetcher,
          console: console,
          archiveIndex: WindowsArchiveIndex(),
        );
      case 'macos':
        return MacOSInstaller(
          versionsPath: versionsPath,
          processManager: processes,
        );
      default:
        return LinuxInstaller(
          versionsPath: versionsPath,
          processManager: processes,
        );
    }
  }
}

/// Wire every command to [deps].
PvmCommandRunner buildRunner(PvmDependencies deps) {
  final os = deps.osManager;
  final console = deps.console;
  final constants = PlatformConstants(deps.platform);
  final resolver = ActiveVersionResolver(SymLinkInspector(os));
  final composerLocator = ComposerLocator(
    platformConstants: constants,
    osManager: os,
  );
  final phpExecutor = PhpExecutor(
    processManager: deps.processManager,
    osManager: os,
    executableResolver: ExecutableResolver(
      platformConstants: constants,
      osManager: os,
    ),
    platformInfo: deps.platform,
  );

  return PvmCommandRunner('pvm', 'PHP Version Manager')
    ..addCommand(InstallCommand(console, deps.installer))
    ..addCommand(ListRemoteCommand(deps.releaseFetcher, console))
    ..addCommand(
      UseCommand(
        os,
        PhpVersionManager(console),
        GitIgnoreService(os, console),
        deps.versionActivator,
        console,
      ),
    )
    ..addCommand(GlobalCommand(os, deps.versionActivator, console))
    ..addCommand(ListCommand(os, console))
    ..addCommand(CurrentCommand(os, resolver, console))
    ..addCommand(
      DoctorCommand(
        osManager: os,
        platformConstants: constants,
        console: console,
        resolver: resolver,
      ),
    )
    ..addCommand(
      UninstallCommand(
        osManager: os,
        symlinkInspector: SymLinkInspector(os),
        console: console,
      ),
    )
    ..addCommand(
      ExecCommand(
        osManager: os,
        platformConstants: constants,
        phpExecutor: phpExecutor,
        processManager: deps.processManager,
        composerLocator: composerLocator,
        resolver: resolver,
        console: console,
      ),
    )
    ..addCommand(PhpCommand(phpExecutor, os, console))
    ..addCommand(ComposerCommand(phpExecutor, os, composerLocator, console))
    ..addCommand(
      SetupCommand(
        osManager: os,
        configurator: deps.environmentConfigurator,
        console: console,
      ),
    )
    ..addCommand(VersionFlag(console));
}

/// Run PVM with [arguments] and return the process exit code.
Future<int> runPvm(List<String> arguments, {PvmDependencies? deps}) async {
  final PvmDependencies resolved;
  try {
    resolved = deps ?? PvmDependencies.forHost();
  } on Exception catch (e) {
    // e.g. no HOME/USERPROFILE (cron, minimal containers): no console yet.
    stderr.writeln('Error: ${describeError(e)}');
    return ExitCode.configurationError;
  }
  final console = resolved.console;

  if (arguments.isNotEmpty &&
      (arguments.first == '--version' || arguments.first == '-v')) {
    console.print('PVM version: $packageVersion');
    return ExitCode.success;
  }

  try {
    return await buildRunner(resolved).run(arguments) ?? ExitCode.success;
  } on UsageException catch (e) {
    console.printError(e.message);
    return ExitCode.usageError;
  } catch (e) {
    console.printError('Unexpected error: $e');
    return ExitCode.generalError;
  }
}
