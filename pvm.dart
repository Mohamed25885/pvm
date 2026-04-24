import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:get_it/get_it.dart';

import 'package:pvm/src/console/console_io.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/platform_info.dart';
import 'package:pvm/src/core/platform_constants.dart';
import 'package:pvm/src/core/os_manager.dart';
import 'package:pvm/src/core/os_manager_factory.dart';
import 'package:pvm/src/core/gitignore_service.dart';
import 'package:pvm/src/core/php_version_manager.dart';
import 'package:pvm/src/core/executable_resolver.dart';
import 'package:pvm/src/core/composer_locator.dart';
import 'package:pvm/src/core/process_manager.dart';
import 'package:pvm/src/interfaces/i_installer.dart';
import 'package:pvm/src/interfaces/i_version_activator.dart';
import 'package:pvm/src/managers/windows_installer.dart';
import 'package:pvm/src/managers/windows_version_activator.dart';
import 'package:pvm/src/managers/linux_installer.dart';
import 'package:pvm/src/managers/linux_version_activator.dart';
import 'package:pvm/src/managers/macos_installer.dart';
import 'package:pvm/src/managers/macos_version_activator.dart';
import 'package:pvm/src/process/io_process_manager.dart';
import 'package:pvm/src/services/php_executor.dart';
import 'package:pvm/src/services/release_fetcher_factory.dart';
import 'package:pvm/src/commands/use_command.dart';
import 'package:pvm/src/commands/global_command.dart';
import 'package:pvm/src/commands/list_command.dart';
import 'package:pvm/src/commands/php_command.dart';
import 'package:pvm/src/commands/composer_command.dart';
import 'package:pvm/src/commands/version_flag.dart';
import 'package:pvm/src/commands/install_command.dart';
import 'package:pvm/src/commands/list_remote_command.dart';
import 'package:pvm/src/version.dart';

final getIt = GetIt.instance;

Future<void> setupServices() async {
  final platformInfo = createPlatformInfo();
  final platformConstants = PlatformConstants(platformInfo);

  getIt.registerSingleton<PlatformInfo>(platformInfo);
  getIt.registerSingleton<PlatformConstants>(platformConstants);
  getIt.registerSingleton<IOSManager>(createOSManager());
  getIt.registerSingleton<IProcessManager>(
    IOProcessManager(osManager: getIt<IOSManager>()),
  );
  getIt.registerSingleton<ConsoleIO>(ConsoleIO());

  getIt.registerSingleton<ExecutableResolver>(
    ExecutableResolver(
      platformConstants: platformConstants,
      osManager: getIt<IOSManager>(),
    ),
  );

  getIt.registerSingleton<ComposerLocator>(
    ComposerLocator(
      platformConstants: platformConstants,
      osManager: getIt<IOSManager>(),
    ),
  );

  getIt.registerSingleton<GitIgnoreService>(
    GitIgnoreService(getIt<IOSManager>(), getIt<ConsoleIO>()),
  );

  getIt.registerSingleton<PhpVersionManager>(
    PhpVersionManager(getIt<ConsoleIO>()),
  );

  getIt.registerSingleton<PhpExecutor>(
    PhpExecutor(
      processManager: getIt<IProcessManager>(),
      osManager: getIt<IOSManager>(),
      executableResolver: getIt<ExecutableResolver>(),
    ),
  );

  // Platform-specific interfaces (Wave 2A)
  // Using PlatformModule pattern - register by platform
  _registerPlatformServices(platformInfo);
}

void _registerPlatformServices(PlatformInfo platformInfo) {
  final osManager = getIt<IOSManager>();
  final versionsPath = osManager.phpVersionsPath;
  final homeDir = osManager.getHomeDirectory();

  if (platformInfo.osType == 'windows') {
    getIt.registerLazySingleton<IInstaller>(
      () => WindowsInstaller(versionsPath: versionsPath),
    );
    getIt.registerLazySingleton<IVersionActivator>(
      () => WindowsVersionActivator(
        versionsPath: versionsPath,
        homeDirectory: homeDir,
      ),
    );
  } else if (platformInfo.osType == 'linux') {
    getIt.registerLazySingleton<IInstaller>(
      () => LinuxInstaller(versionsPath: versionsPath),
    );
    getIt.registerLazySingleton<IVersionActivator>(
      () => LinuxVersionActivator(
        versionsPath: versionsPath,
        homeDirectory: homeDir,
      ),
    );
  } else if (platformInfo.osType == 'macos') {
    getIt.registerLazySingleton<IInstaller>(
      () => MacOSInstaller(versionsPath: versionsPath),
    );
    getIt.registerLazySingleton<IVersionActivator>(
      () => MacOSVersionActivator(
        versionsPath: versionsPath,
        homeDirectory: homeDir,
      ),
    );
  }
}

class PvmCommandRunner extends CommandRunner<int> {
  PvmCommandRunner(String name, String description) : super(name, description);

  ArgParser? _parser;
  @override
  ArgParser get argParser => _parser ??= ArgParser(allowTrailingOptions: true);
}

Future<int> main(List<String> arguments) async {
  await setupServices();

  final osManager = getIt<IOSManager>();
  final console = getIt<ConsoleIO>();
  final phpExecutor = getIt<PhpExecutor>();
  final composerLocator = getIt<ComposerLocator>();
  final gitIgnoreService = getIt<GitIgnoreService>();
  final phpVersionManager = getIt<PhpVersionManager>();

  final runner = PvmCommandRunner('pvm', 'PHP Version Manager');

  final fetcher = createReleaseFetcher();
  final installer = getIt<IInstaller>();

  runner.addCommand(InstallCommand(fetcher, console, installer));
  runner.addCommand(ListRemoteCommand(fetcher, console));

  runner.addCommand(UseCommand(
    osManager,
    phpVersionManager,
    gitIgnoreService,
    getIt<IVersionActivator>(),
    console,
  ));
  runner.addCommand(GlobalCommand(osManager, getIt<IVersionActivator>(), console));
  runner.addCommand(ListCommand(osManager, console));
  runner.addCommand(PhpCommand(phpExecutor, osManager, console));
  runner.addCommand(ComposerCommand(
    phpExecutor,
    osManager,
    composerLocator,
    console,
  ));
  runner.addCommand(VersionFlag(console));

  if (arguments.isNotEmpty && (arguments.first == '--version' || arguments.first == '-v')) {
    console.print('PVM version: $packageVersion');
    return ExitCode.success;
  }

  try {
    return await runner.run(arguments) ?? ExitCode.success;
  } on UsageException catch (e) {
    console.printError(e.message);
    return ExitCode.usageError;
  } catch (e) {
    console.printError('Unexpected error: $e');
    return ExitCode.generalError;
  }
}
