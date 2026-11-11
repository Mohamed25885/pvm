import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/console.dart';
import '../core/error_text.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../core/version_label.dart';
import '../domain/exceptions.dart';
import '../domain/exceptions/probe_exception.dart';
import '../domain/install_record.dart';
import '../domain/php_version.dart';
import '../domain/version_registry.dart';
import '../interfaces/i_installer.dart';
import '../services/folder_probe.dart';

/// `pvm link <X.Y> <folder>` — adopt a PHP folder the user already has as
/// the slot `versions/<X.Y>`. PVM never writes inside the folder.
class LinkCommand extends Command<int> {
  @override
  final String name = 'link';

  @override
  final String description =
      'Use an existing PHP folder (Plesk, Remi, Homebrew, a self-build…) '
      'as a version';

  @override
  final String invocation = 'pvm link <X.Y> <folder>';

  final IOSManager _os;
  final FolderProbe _probe;
  final Console _console;

  LinkCommand(this._os, this._probe, this._console);

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 2) {
      _console.printError('Usage: $invocation');
      return ExitCode.usageError;
    }

    final PhpVersion version;
    try {
      version = PhpVersion.parse(rest[0]);
    } on InvalidVersionFormatException catch (e) {
      _console.printError(e.message);
      return ExitCode.usageError;
    }
    if (version.hasPatch) {
      _console.printError(
        'A link takes a minor version like ${version.slot}, not ${rest[0]}.',
      );
      return ExitCode.usageError;
    }

    final registry = VersionRegistry(_os);
    final slotPath = registry.getVersionPath(version);
    final recordPath = registry.linkRecordPath(version.slot);
    if (await _os.directoryExists(slotPath) ||
        await _os.isSymLink(slotPath) ||
        await _os.fileExists(recordPath)) {
      final held = [
        for (final s in await registry.installedSlots())
          if (s.version.slot == version.slot)
            versionLabel(version, s.record?.version),
      ];
      _console.printError(
        SlotFilledException(
          version.slot,
          held.isEmpty ? version.slot : held.first,
        ).toString(),
      );
      return ExitCode.generalError;
    }

    final folder = p.normalize(p.absolute(rest[1]));
    final ProbeResult probed;
    try {
      probed = await _probe.probe(folder);
    } on ProbeException catch (e) {
      _console.printError(e.toString());
      return ExitCode.usageError;
    }
    if (probed.version.split('.').take(2).join('.') != version.slot) {
      _console.printError(
        'That folder has PHP ${probed.version}, not ${version.slot}',
      );
      return ExitCode.usageError;
    }

    final record = InstallRecord(
      version: probed.version,
      sourceUrl: folder,
      archiveSha256: '',
      verified: false,
      installedAt: DateTime.now().toUtc(),
      files: const {},
      kind: SlotKind.linked,
      zts: probed.zts,
      arch: probed.arch,
      apiNo: probed.apiNo,
      phpConfig: probed.phpConfig,
      prefix: probed.prefix,
      extensionDir: probed.extensionDir,
      writable: probed.writable,
      vsVersion: probed.vsVersion,
    );
    try {
      await record.writeToFile(recordPath);
      await _os.createSymLink(version.slot, folder, slotPath);
    } catch (e) {
      try {
        await _os.deleteSymLink(slotPath);
      } catch (_) {}
      await _deleteQuietly(recordPath);
      _console.printError('Could not link $folder: ${describeError(e)}');
      return ExitCode.generalError;
    }

    _console.print('Linked ${versionLabel(version, probed.version)} → $folder');
    return ExitCode.success;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
