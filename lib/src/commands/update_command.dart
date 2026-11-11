import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

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
import '../domain/php_release.dart';
import '../domain/php_version.dart';
import '../domain/version_registry.dart';
import '../interfaces/i_installer.dart';
import '../services/build_tools.dart';
import '../services/extensions/extension_artifact.dart';
import '../services/release_fetcher.dart';
import '../services/slot_ini.dart';
import 'ext_command.dart' show ExtensionRoute;

/// `pvm update <X.Y>`: moves a slot to the newest patch of its minor through
/// the install pipeline (staging, then an atomic swap), keeping the user's
/// extensions.
class UpdateCommand extends Command<int> {
  @override
  final String name = 'update';

  @override
  final String description =
      'Update an installed PHP version to its newest patch';

  @override
  String get invocation => 'pvm update <X.Y>';

  final IOSManager _os;
  final IInstaller _installer;

  /// Rebuilds `source` slots; null on Windows.
  final IInstaller? _sourceInstaller;
  final IProcessManager _pm;
  final PlatformInfo _platform;
  final Console _console;
  final ExtensionRoute Function() _sourceBuilder;

  UpdateCommand({
    required IOSManager osManager,
    required this._installer,
    this._sourceInstaller,
    required IProcessManager processManager,
    required this._platform,
    required this._console,
    required this._sourceBuilder,
  }) : _os = osManager,
       _pm = processManager {
    argParser.addFlag(
      'allow-unverified',
      help:
          'Allow archived builds that have no published SHA-256 '
          '(older patch releases).',
      negatable: false,
    );
  }

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) usageException('Name one version, such as 8.4.');
    final PhpVersion version;
    try {
      version = PhpVersion.parse(rest.single);
    } on InvalidVersionFormatException catch (e) {
      usageException(e.message);
    }
    final x = version.slot;
    if (version.hasPatch) {
      usageException(
        'pvm update takes X.Y (such as $x); it always goes to the newest '
        'patch.',
      );
    }

    final slots = await VersionRegistry(_os).installedSlots();
    final slot = slots.where((s) => s.version.slot == x).firstOrNull;
    if (slot == null) {
      final installed = [
        for (final s in slots) versionLabel(s.version, s.record?.version),
      ];
      _console.printError(
        'PHP $x is not installed. '
        '${installed.isEmpty ? 'No versions are installed.' : 'Installed: ${installed.join(', ')}'}',
      );
      return ExitCode.versionNotFound;
    }
    final record = slot.record;
    if (record == null) {
      _console.printError(
        'PHP $x has no install record. Reinstall it (pvm install $x --force).',
      );
      return ExitCode.generalError;
    }
    final old = versionLabel(slot.version, record.version);

    final IInstaller installer;
    final Future<void> Function(String staged) beforeSwap;
    switch (record.kind) {
      case SlotKind.linked:
        _console.printError(
          '$x is linked to ${VersionRegistry.slotFolder(slot.path)}; '
          'update it there.',
        );
        return ExitCode.generalError;
      case SlotKind.source:
        final source = _sourceInstaller;
        if (source == null) {
          _console.printError('$x is a source build; build it on Linux/macOS.');
          return ExitCode.generalError;
        }
        installer = source;
        // Extensions are rebuilt against the committed slot (below).
        beforeSwap = (staged) => _keepIni(slot.path, record, staged);
      case SlotKind.static:
      case SlotKind.windowsZip:
        installer = _installer;
        beforeSwap = (staged) => _carry(slot.path, record, staged);
    }

    try {
      final result = await installer.install(
        x,
        options: InstallOptions(
          // Same build as before: an x86 TS slot stays x86 TS.
          architecture: PhpRelease.architectureFromString(record.arch),
          buildType: record.zts ? BuildType.ts : BuildType.nts,
          allowUnverified: argResults!['allow-unverified'] as bool,
          update: beforeSwap,
        ),
      );
      if (result.alreadyInstalled) {
        _console.print('$old is up to date');
        return ExitCode.success;
      }
      if (record.kind == SlotKind.source) {
        await _rebuild(slot.path, record.extensions);
      }
      _console.print('Updated $old → ${versionLabel(version, result.version)}');
      return ExitCode.success;
    } on SlotInUseException catch (e) {
      _console.printError(e.toString());
      return ExitCode.slotInUse;
    } on ExtensionLoadException catch (e) {
      _console.printError('$x was not updated: ${e.message}');
      return ExitCode.buildFailed;
    } on ReleaseFetcherException catch (e) {
      _console.printError('Network error: ${e.message}');
      return ExitCode.generalError;
    } on NoMatchingReleaseException catch (e) {
      _console.printError(e.message);
      return ExitCode.versionNotFound;
    } on UnverifiedReleaseException catch (e) {
      _console.printError(e.toString());
      return ExitCode.generalError;
    } on MissingToolsException catch (e) {
      _console.printError('Missing build tools: ${e.missing.join(', ')}');
      _console.print(e.installCommand);
      return ExitCode.toolMissing;
    } on Exception catch (e) {
      _console.printError('Update failed: ${describeError(e)}');
      return ExitCode.generalError;
    } finally {
      try {
        await installer.dispose();
      } catch (_) {}
    }
  }

  /// Copies every file of [oldSlot] that its archive did not ship (extension
  /// and dependency DLLs, conf.d inis, an edited php.ini) into [staged],
  /// unless the new archive ships that path; keeps the recorded extensions
  /// and checks each still loads in the staged PHP.
  Future<void> _carry(String oldSlot, InstallRecord old, String staged) async {
    final fresh = (await InstallRecord.readFrom(staged))!;
    final root = p.normalize(p.absolute(oldSlot));
    await for (final e in Directory(
      root,
    ).list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final rel = p.posix.joinAll(p.split(p.relative(e.path, from: root)));
      if (rel == InstallRecord.fileName ||
          old.files.containsKey(rel) ||
          fresh.files.containsKey(rel)) {
        continue;
      }
      final to = File(p.join(staged, rel));
      await to.parent.create(recursive: true);
      await e.copy(to.path);
    }
    final record = fresh.copyWith(extensions: old.extensions);
    await record.writeTo(staged);
    final php = PhpLayout.forPlatform(_platform).phpExecutable(staged);
    for (final ext in old.extensions) {
      await checkLoads(_pm, php, SlotIni(staged, record, _platform), ext.name);
    }
  }

  /// A source build's `etc/php.ini` and its `etc/conf.d` inis move to
  /// [staged]; the inis of recorded extensions are skipped, as the rebuild
  /// writes them again. The user's php.ini replaces whatever staging has.
  Future<void> _keepIni(
    String oldSlot,
    InstallRecord old,
    String staged,
  ) async {
    final ini = File(p.join(oldSlot, 'etc', 'php.ini'));
    if (await ini.exists()) {
      await Directory(p.join(staged, 'etc')).create(recursive: true);
      await ini.copy(p.join(staged, 'etc', 'php.ini'));
    }
    final confD = Directory(p.join(oldSlot, 'etc', 'conf.d'));
    if (!await confD.exists()) return;
    final rebuilt = {
      for (final e in old.extensions) ...[
        '50-${e.name}.ini',
        '50-${e.name}.ini.disabled',
      ],
    };
    final to = Directory(p.join(staged, 'etc', 'conf.d'));
    await for (final f in confD.list(followLinks: false)) {
      final name = p.basename(f.path);
      if (f is! File || rebuilt.contains(name)) continue;
      final dest = File(p.join(to.path, name));
      if (await dest.exists()) continue;
      await to.create(recursive: true);
      await f.copy(dest.path);
    }
  }

  /// Rebuilds each of [extensions] against the updated source slot; one that
  /// fails is dropped from the record with how to reinstall it.
  Future<void> _rebuild(
    String slotPath,
    List<ExtensionEntry> extensions,
  ) async {
    if (extensions.isEmpty) return;
    final record = (await VersionRegistry.readSlotRecord(slotPath))!;
    final slot = InstalledSlot(
      PhpVersion.parse(record.version),
      slotPath,
      record,
    );
    final kept = <ExtensionEntry>[];
    for (final ext in extensions) {
      final route = _sourceBuilder();
      try {
        kept.add(await route.install(ext.name, slot));
      } on Exception {
        _console.printWarning(
          '${ext.name} could not be rebuilt; run: pvm ext install ${ext.name}',
        );
      } finally {
        route.dispose();
      }
    }
    await VersionRegistry.writeSlotRecord(
      slotPath,
      record.copyWith(extensions: kept),
    );
  }
}
