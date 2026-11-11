import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/active_version_resolver.dart';
import '../core/console.dart';
import '../core/error_text.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../core/php_layout.dart';
import '../core/platform_info.dart';
import '../core/process_manager.dart';
import '../core/version_label.dart';
import '../domain/exceptions.dart';
import '../domain/install_record.dart';
import '../domain/php_version.dart';
import '../domain/project.dart';
import '../domain/version_registry.dart';
import '../services/build_tools.dart';
import '../services/extensions/extension_artifact.dart';
import '../services/extensions/pecl_download.dart';
import '../services/folder_probe.dart';
import '../services/slot_ini.dart';

/// One way to install an extension into a slot (`PeclSourceBuilder`,
/// `PeclWindowsDll`). [dispose] runs after every install, failed or not.
typedef ExtensionRoute = ({
  Future<ExtensionEntry> Function(
    String ext,
    InstalledSlot slot, {
    String? confDir,
  })
  install,
  void Function() dispose,
});

/// `pvm ext <subcommand>`.
class ExtCommand extends Command<int> {
  @override
  final String name = 'ext';

  @override
  final String description = 'Manage PHP extensions of an installed version';

  ExtCommand(ExtInstallCommand install) {
    addSubcommand(install);
  }
}

/// `pvm ext install <ext> [--version=X.Y]`.
class ExtInstallCommand extends Command<int> {
  @override
  final String name = 'install';

  @override
  final String description = 'Install a PECL extension into one PHP version';

  @override
  String get invocation => 'pvm ext install <ext> [--version=X.Y]';

  final IOSManager _os;
  final ActiveVersionResolver _resolver;
  final IProcessManager _pm;
  final PlatformInfo _platform;
  final Console _console;
  final ExtensionRoute Function() _sourceBuilder;
  final ExtensionRoute Function() _windowsDll;

  ExtInstallCommand({
    required IOSManager osManager,
    required this._resolver,
    required IProcessManager processManager,
    required this._platform,
    required this._console,
    required this._sourceBuilder,
    required this._windowsDll,
  }) : _os = osManager,
       _pm = processManager {
    argParser.addOption(
      'version',
      help: 'PHP version (X.Y) to install into. Default: the active version.',
      valueHelp: 'X.Y',
    );
  }

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) usageException('Name one extension.');
    final ext = rest.single;
    ExtensionArtifact.validateName(ext); // before ext reaches a path or URL

    final (slot: found, :code) = await _target(
      argResults!['version'] as String?,
    );
    if (found == null) return code;
    final x = found.version.slot;
    if (found.record == null) {
      _console.printError(
        'PHP $x has no install record. Reinstall it '
        '(pvm install $x --force) or link it (pvm link $x <folder>).',
      );
      return ExitCode.generalError;
    }
    final record = await FolderProbe(
      _pm,
      _platform,
    ).backfill(found.path, found.record!);
    final slot = InstalledSlot(found.version, found.path, record);
    final label = versionLabel(slot.version, record.version);

    try {
      await checkLoads(
        _pm,
        PhpLayout.forPlatform(_platform).phpExecutable(slot.path),
        SlotIni(slot.path, record, _platform),
        ext,
      );
      _console.print('$ext is already enabled for $label');
      return ExitCode.success;
    } catch (_) {
      // Not loaded (or PHP would not run): the route reports a broken slot.
    }

    final windows = _platform.osType == 'windows';
    final ExtensionRoute Function() route;
    String? confDir;
    switch (record.kind) {
      case SlotKind.static:
        _console.printError(
          "$ext isn't in this build. Run: pvm install $x --from-source "
          '--force, or pvm link $x <folder>',
        );
        return ExitCode.generalError;
      case SlotKind.windowsZip:
        route = _windowsDll;
      case SlotKind.source:
        route = _sourceBuilder;
      case SlotKind.linked:
        final folder = VersionRegistry.slotFolder(slot.path);
        if (!record.writable) {
          if (windows) {
            _console.printError(
              '$folder is not writable; install $ext there yourself',
            );
          } else {
            _console.printError('$folder is not writable by PVM. Run:');
            _console.print(
              systemInstallCommand(record.prefix ?? folder, x, ext),
            );
          }
          return ExitCode.toolMissing;
        }
        if (windows) {
          route = _windowsDll;
        } else if (record.phpConfig == null) {
          _console.printError(
            "$ext can't be built for $x: $folder has no php-config",
          );
          return ExitCode.generalError;
        } else {
          route = _sourceBuilder;
        }
        // The extension is enabled where the folder's own PHP scans for ini.
        confDir = await _writableScanDir(folder);
        if (confDir == null) {
          _console.printError(
            "$folder's PHP has no writable ini scan dir; "
            'install $ext there yourself',
          );
          return ExitCode.toolMissing;
        }
    }
    return _install(route(), ext, slot, record, label, confDir);
  }

  Future<int> _install(
    ExtensionRoute route,
    String ext,
    InstalledSlot slot,
    InstallRecord record,
    String label,
    String? confDir,
  ) async {
    try {
      final entry = await route.install(ext, slot, confDir: confDir);
      await VersionRegistry.writeSlotRecord(
        slot.path,
        record.copyWith(
          extensions: [
            for (final e in record.extensions)
              if (e.name != ext) e,
            entry,
          ],
        ),
      );
      _console.print('Installed $ext ${entry.version} for $label');
      return ExitCode.success;
    } on MissingToolsException catch (e) {
      _console.printError('Missing build tools: ${e.missing.join(', ')}');
      _console.print(e.installCommand);
      return ExitCode.toolMissing;
    } on ExtensionUnavailableException catch (e) {
      _console.printError(e.message);
      return ExitCode.extensionUnavailable;
    } on ExtensionLoadException catch (e) {
      _console.printError(e.message);
      return ExitCode.buildFailed;
    } on ExtensionBuildException catch (e) {
      _console.printError(e.message);
      return ExitCode.buildFailed;
    } on SlotBrokenException catch (e) {
      _console.printError(e.message);
      return ExitCode.generalError;
    } on Exception catch (e) {
      _console.printError('Could not install $ext: ${describeError(e)}');
      return ExitCode.generalError;
    } finally {
      route.dispose();
    }
  }

  /// The `Scan for additional .ini files in:` dir of [folder]'s PHP, or null
  /// when it has none or PVM cannot write there.
  Future<String?> _writableScanDir(String folder) async {
    try {
      final r = await _pm.runCaptured(
        ProcessSpec(
          executable: PhpLayout.forPlatform(_platform).phpExecutable(folder),
          arguments: ['--ini'],
        ),
      );
      final dir = RegExp(
        r'^Scan for additional \.ini files in:\s*(.+?)\s*$',
        multiLine: true,
      ).firstMatch(r.stdout)?[1];
      // shortcut: a multi-path PHP_INI_SCAN_DIR is refused as missing;
      // split it if users hit that.
      if (dir == null || dir == '(none)') return null;
      final probe = File(p.join(dir, '.pvm-write-test'));
      await probe.writeAsString(''); // throws when missing or read-only
      await probe.delete();
      return dir;
    } on Exception {
      return null;
    }
  }

  /// The slot for `--version`, else the active one (local, then global).
  /// Without one, prints why and returns the exit code.
  Future<({InstalledSlot? slot, int code})> _target(String? wanted) async {
    final slots = await VersionRegistry(_os).installedSlots();
    final PhpVersion version;
    if (wanted != null) {
      try {
        version = PhpVersion.parse(wanted);
      } on InvalidVersionFormatException {
        usageException('--version takes a PHP version such as 8.4');
      }
    } else {
      final project = await Project.locate(_os);
      final active = await _resolver.resolve(
        projectRoot: project.rootDirectory.path,
      );
      if (active.isNone) {
        _console.printError(
          'No PHP version is active here. Run pvm use <X.Y> or '
          'pvm global <X.Y>, or pass --version=X.Y',
        );
        return (slot: null, code: ExitCode.configurationError);
      }
      version = active.version!;
    }
    for (final s in slots) {
      if (s.version.slot == version.slot &&
          (!version.hasPatch || version == s.version)) {
        return (slot: s, code: ExitCode.success);
      }
    }
    final installed = [
      for (final s in slots) versionLabel(s.version, s.record?.version),
    ];
    _console.printError(
      'PHP $version is not installed. '
      '${installed.isEmpty ? 'No versions are installed.' : 'Installed: ${installed.join(', ')}'}',
    );
    return (slot: null, code: ExitCode.versionNotFound);
  }
}

/// The system's own install command for [ext] on a non-writable linked PHP
/// whose `php-config --prefix` is [prefix] (PVM never runs it).
String systemInstallCommand(String prefix, String x, String ext) {
  if (prefix == '/usr') return 'sudo apt install php$x-$ext';
  final remi = RegExp(r'^/opt/remi/(php\d+)/root/usr$').firstMatch(prefix);
  if (remi != null) return 'sudo dnf install ${remi[1]}-php-pecl-$ext';
  // cPanel's /opt/cpanel/ea-phpXY/root/usr and Plesk both ship their own pecl.
  return '$prefix/bin/pecl install $ext';
}
