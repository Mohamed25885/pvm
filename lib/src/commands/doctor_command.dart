import 'dart:convert';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../core/active_version_resolver.dart';
import '../core/console.dart';
import '../core/exit_codes.dart';
import '../core/os_manager.dart';
import '../core/platform_constants.dart';
import '../services/diagnostics/diagnostic_models.dart';
import '../services/diagnostics/doctor_checks.dart';

/// `pvm doctor` — environment diagnostics (npm-doctor style).
class DoctorCommand extends Command<int> {
  @override
  final String name = 'doctor';

  @override
  final String description = 'Run diagnostics for the PVM installation';

  @override
  final ArgParser argParser = ArgParser()
    ..addFlag(
      'json',
      help: 'Emit machine-readable JSON instead of the human report.',
      negatable: false,
    )
    ..addFlag(
      'no-symlink-test',
      help: 'Skip the live symlink-creation probe.',
      negatable: false,
    );

  final IOSManager _osManager;
  final PlatformConstants _platformConstants;
  final Console _console;
  final ActiveVersionResolver _resolver;

  DoctorCommand({
    required IOSManager osManager,
    required PlatformConstants platformConstants,
    required Console console,
    required ActiveVersionResolver resolver,
  }) : _osManager = osManager,
       _platformConstants = platformConstants,
       _console = console,
       _resolver = resolver;

  @override
  Future<int> run() async {
    final asJson = argResults!['json'] as bool;
    final noSymlinkTest = argResults!['no-symlink-test'] as bool;

    final checks = <Future<DiagnosticResult> Function()>[
      () => PvmInstallationCheck(_osManager).run(),
      () => PlatformCheck(_osManager, _platformConstants).run(),
      () => VersionsDirectoryCheck(_osManager).run(),
      () => InstalledVersionsCheck(_osManager, _platformConstants).run(),
      () => ActiveVersionsCheck(_resolver).run(),
      () => SymlinkProbeCheck(_osManager, enabled: !noSymlinkTest).run(),
      () => HomeWritableCheck(_osManager).run(),
      () => PathContainsGlobalCheck(_osManager, _platformConstants).run(),
      () => ProjectPvmrcCheck(_osManager).run(),
    ];

    final results = <DiagnosticResult>[];
    var index = 0;
    for (final runCheck in checks) {
      try {
        results.add(await runCheck());
      } catch (e, st) {
        results.add(
          DiagnosticResult(
            id: 'check-$index',
            label: 'Check $index',
            status: DiagnosticStatus.fail,
            lines: ['Unexpected error: $e', st.toString().split('\n').first],
          ),
        );
      }
      index++;
    }

    if (asJson) {
      _console.print(_jsonPayload(results));
    } else {
      _renderHuman(results);
    }

    final failCount = results.where((r) => r.isFail).length;
    if (failCount == 0) return ExitCode.success;

    final symlinkFailed = results.any(
      (r) => r.id == 'symlink-probe' && r.isFail,
    );
    if (symlinkFailed) return ExitCode.permissionDenied;

    return ExitCode.generalError;
  }

  void _renderHuman(List<DiagnosticResult> results) {
    _console.print('pvm doctor - diagnostics');
    _console.print('');

    var ok = 0;
    var warn = 0;
    var fail = 0;

    for (final r in results) {
      switch (r.status) {
        case DiagnosticStatus.ok:
        case DiagnosticStatus.info:
          ok++;
          break;
        case DiagnosticStatus.warn:
          warn++;
          break;
        case DiagnosticStatus.fail:
          fail++;
          break;
      }

      final tag = switch (r.status) {
        DiagnosticStatus.ok => '[ok]  ',
        DiagnosticStatus.info => '[info]',
        DiagnosticStatus.warn => '[warn]',
        DiagnosticStatus.fail => '[fail]',
      };

      _console.print('$tag ${r.label}');
      for (final line in r.lines) {
        _console.print('       $line');
      }
      _console.print('');
    }

    _console.print('Summary: $ok ok, $warn warn, $fail fail');
  }

  String _jsonPayload(List<DiagnosticResult> results) {
    final list = results
        .map(
          (r) => {
            'id': r.id,
            'label': r.label,
            'status': r.status.name,
            'lines': r.lines,
          },
        )
        .toList();
    return const JsonEncoder.withIndent('  ').convert({'checks': list});
  }
}
