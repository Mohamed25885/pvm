import 'dart:convert';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/active_version_resolver.dart';
import '../core/console.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../core/symlink_inspector.dart';
import '../domain/exceptions.dart';
import '../domain/php_version.dart';
import '../domain/project.dart';

/// `pvm current` — display the active PHP version (global and/or local).
///
/// Implements the spec's precedence rule: a local `.pvm` symlink in the
/// project root overrides the global `<home>/.pvm` symlink. The command
/// surfaces broken/orphaned/corrupt symlinks rather than silently treating
/// them as "not set", and emits structured JSON when `--json` is supplied.
class CurrentCommand extends Command<int> {
  @override
  final String name = 'current';

  @override
  final String description =
      'Display the currently active PHP version (global and/or local)';

  @override
  final ArgParser argParser = ArgParser()
    ..addFlag(
      'json',
      help: 'Emit machine-readable JSON instead of the human report.',
      negatable: false,
    )
    ..addFlag(
      'global-only',
      help: 'Restrict the report to the global scope.',
      negatable: false,
    )
    ..addFlag(
      'local-only',
      help: 'Restrict the report to the local scope.',
      negatable: false,
    );

  final IOSManager _osManager;
  final ActiveVersionResolver _resolver;
  final Console _console;

  CurrentCommand(this._osManager, this._resolver, this._console);

  @override
  Future<int> run() async {
    final flags = argResults!;

    final globalOnly = flags['global-only'] as bool;
    final localOnly = flags['local-only'] as bool;
    final asJson = flags['json'] as bool;

    if (globalOnly && localOnly) {
      _console.printError(
        '--global-only and --local-only are mutually exclusive',
      );
      return ExitCode.usageError;
    }

    final project = await Project.findFromPath(_osManager.currentDirectory);
    final active = await _resolver.resolve(
      projectRoot: project.rootDirectory.path,
    );

    PhpVersion? declared;
    try {
      declared = await project.getConfiguredVersion();
    } on InvalidVersionFormatException {
      declared = null;
    }

    if (asJson) {
      _console.print(
        _renderJson(
          active,
          declared,
          globalOnly: globalOnly,
          localOnly: localOnly,
        ),
      );
    } else {
      _renderHuman(
        active,
        declared,
        globalOnly: globalOnly,
        localOnly: localOnly,
      );
    }

    return active.isNone ? ExitCode.configurationError : ExitCode.success;
  }

  void _renderHuman(
    ActiveVersion active,
    PhpVersion? declared, {
    required bool globalOnly,
    required bool localOnly,
  }) {
    _console.print('PVM - Current PHP Version');
    _console.print('');

    if (!localOnly) {
      _renderScope(
        'Global',
        active.global,
        isEffective: active.scope == VersionScope.global,
      );
    }

    if (!globalOnly) {
      _renderScope(
        'Local',
        active.local,
        isEffective: active.scope == VersionScope.local,
        declaredVersion: declared,
      );
    }

    _console.print('');
    if (active.isNone) {
      _console.print('Effective: none');
    } else {
      final scopeLabel = active.scope == VersionScope.local
          ? 'local'
          : 'global';
      _console.print('Effective: ${active.version} ($scopeLabel)');
    }
  }

  void _renderScope(
    String label,
    SymLinkInfo info, {
    required bool isEffective,
    PhpVersion? declaredVersion,
  }) {
    switch (info.status) {
      case SymLinkStatus.notSet:
        _console.print('$label   : not set');
        if (label == 'Local') {
          _console.print('  No local version exists in this project.');
          _console.print('  Hint: run `pvm use <version>` to set one.');
        }
        break;
      case SymLinkStatus.ok:
        final marker = isEffective ? ' (effective)' : '';
        _console.print('$label   : ${info.version}$marker');
        _console.print('  link  : ${info.linkPath}');
        _console.print('  -> ok : ${info.target}');
        if (label == 'Local' && declaredVersion != null) {
          if (info.version != declaredVersion) {
            _console.print('  declared in .pvmrc: $declaredVersion (mismatch)');
            _console.print(
              '  Hint: run `pvm use` to re-activate the declared version.',
            );
          } else {
            _console.print('  declared in .pvmrc: $declaredVersion');
          }
        }
        break;
      case SymLinkStatus.broken:
        _console.print('$label   : BROKEN');
        _console.print('  link  : ${info.linkPath}');
        _console.print(
          '  -> X  : ${info.target ?? '(unreadable)'} (target missing)',
        );
        _console.print(
          '  Hint: run `pvm ${label.toLowerCase()} <version>` to repair, '
          'or `pvm doctor`.',
        );
        break;
      case SymLinkStatus.orphaned:
        _console.print('$label   : ORPHANED');
        _console.print('  link  : ${info.linkPath}');
        _console.print('  -> ?  : ${info.target}');
        _console.print(
          '  Hint: target is outside the pvm versions directory; '
          'was this created by pvm?',
        );
        break;
      case SymLinkStatus.corrupt:
        _console.print('$label   : CORRUPT');
        _console.print('  link  : ${info.linkPath}');
        _console.print(
          '  Slot exists but is not a symbolic link. '
          'Run `pvm doctor` to investigate.',
        );
        break;
    }
    _console.print('');
  }

  String _renderJson(
    ActiveVersion active,
    PhpVersion? declared, {
    required bool globalOnly,
    required bool localOnly,
  }) {
    final payload = <String, Object?>{};
    if (!localOnly) {
      payload['global'] = _scopeJson(active.global);
    }
    if (!globalOnly) {
      payload['local'] = {
        ..._scopeJson(active.local),
        'declaredVersion': declared?.toString(),
        'drift':
            declared != null &&
            active.local.version != null &&
            declared != active.local.version,
      };
    }
    payload['effective'] = {
      'scope': active.scope.name,
      'version': active.version?.toString(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Map<String, Object?> _scopeJson(SymLinkInfo info) => {
    'status': info.status.name,
    'version': info.version?.toString(),
    'link': info.linkPath,
    'target': info.target,
  };
}
