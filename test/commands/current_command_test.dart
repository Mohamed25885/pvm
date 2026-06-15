import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/commands/current_command.dart';
import 'package:pvm/src/core/active_version_resolver.dart';
import 'package:pvm/src/core/constants.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/symlink_inspector.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

class _Harness {
  final MockOSManager osManager = MockOSManager()
    ..mockHomeDir = r'C:\Users\sam'
    ..mockProgramDir = r'C:\pvm';
  final MockConsole console = MockConsole();
  late final SymLinkInspector inspector = SymLinkInspector(osManager);
  late final ActiveVersionResolver resolver = ActiveVersionResolver(inspector);

  late final Directory tempProjectDir;

  Future<void> initProject({String? phpVersionContent}) async {
    tempProjectDir = await Directory.systemTemp.createTemp('pvm_current_cmd_');
    osManager.mockCurrentDirectory = tempProjectDir.path;
    if (phpVersionContent != null) {
      await File(
        p.join(tempProjectDir.path, PvmConstants.pvmrcFileName),
      ).writeAsString(phpVersionContent);
    }
  }

  Future<void> cleanup() async {
    if (await tempProjectDir.exists()) {
      await tempProjectDir.delete(recursive: true);
    }
  }

  String get globalLink =>
      p.join(osManager.mockHomeDir, PvmConstants.pvmDirName);
  String get localLink => p.join(tempProjectDir.path, PvmConstants.pvmDirName);
  String versionDir(String version) =>
      p.join(osManager.phpVersionsPath, version);

  void wireGlobal(String version) {
    osManager.symlinkTargets[globalLink] = versionDir(version);
    osManager.setDirectoryExistsResult(versionDir(version), true);
  }

  void wireLocal(String version) {
    osManager.symlinkTargets[localLink] = versionDir(version);
    osManager.setDirectoryExistsResult(versionDir(version), true);
  }

  Future<int> run(List<String> args) async {
    final runner = CommandRunner<int>('pvm', 'test');
    runner.addCommand(CurrentCommand(osManager, resolver, console));
    return await runner.run(['current', ...args]) ?? 1;
  }
}

void main() {
  group('CurrentCommand', () {
    test('reports both scopes when global only is set', () async {
      final h = _Harness();
      await h.initProject();
      try {
        h.wireGlobal('8.2.10');

        final code = await h.run([]);

        expect(code, equals(ExitCode.success));
        final out = h.console.printed.join('\n');
        expect(out, contains('Global'));
        expect(out, contains('8.2.10'));
        expect(out, contains('Local'));
        expect(out, contains('not set'));
        expect(out, contains('Effective: 8.2.10 (global)'));
      } finally {
        await h.cleanup();
      }
    });

    test('local overrides global in effective line', () async {
      final h = _Harness();
      await h.initProject();
      try {
        h.wireGlobal('8.2.10');
        h.wireLocal('8.3.0');

        final code = await h.run([]);

        expect(code, equals(ExitCode.success));
        final out = h.console.printed.join('\n');
        expect(out, contains('Effective: 8.3.0 (local)'));
      } finally {
        await h.cleanup();
      }
    });

    test('reports broken global symlink', () async {
      final h = _Harness();
      await h.initProject();
      try {
        h.osManager.symlinkTargets[h.globalLink] = h.versionDir('9.9.9');
        h.osManager.setDirectoryExistsResult(h.versionDir('9.9.9'), false);

        final code = await h.run([]);

        expect(code, equals(ExitCode.configurationError));
        final out = h.console.printed.join('\n');
        expect(out, contains('BROKEN'));
      } finally {
        await h.cleanup();
      }
    });

    test('returns configurationError when neither scope is ok', () async {
      final h = _Harness();
      await h.initProject();
      try {
        final code = await h.run([]);

        expect(code, equals(ExitCode.configurationError));
        final out = h.console.printed.join('\n');
        expect(out, contains('Effective: none'));
      } finally {
        await h.cleanup();
      }
    });

    test('flags drift when local link version differs from .pvmrc', () async {
      final h = _Harness();
      await h.initProject(phpVersionContent: '8.2.10');
      try {
        h.wireLocal('8.3.0');

        final code = await h.run([]);

        expect(code, equals(ExitCode.success));
        final out = h.console.printed.join('\n');
        expect(out, contains('mismatch'));
      } finally {
        await h.cleanup();
      }
    });

    test('--global-only and --local-only are mutually exclusive', () async {
      final h = _Harness();
      await h.initProject();
      try {
        final code = await h.run(['--global-only', '--local-only']);

        expect(code, equals(ExitCode.usageError));
      } finally {
        await h.cleanup();
      }
    });

    test('--json emits structured payload', () async {
      final h = _Harness();
      await h.initProject();
      try {
        h.wireGlobal('8.2.10');
        h.wireLocal('8.3.0');

        final code = await h.run(['--json']);

        expect(code, equals(ExitCode.success));
        final out = h.console.printed.join('\n');
        final decoded = jsonDecode(out) as Map<String, dynamic>;
        expect(decoded['effective']['scope'], equals('local'));
        expect(decoded['effective']['version'], equals('8.3.0'));
        expect((decoded['global'] as Map<String, dynamic>)['status'], 'ok');
        expect((decoded['local'] as Map<String, dynamic>)['status'], 'ok');
      } finally {
        await h.cleanup();
      }
    });

    test('--global-only suppresses local section', () async {
      final h = _Harness();
      await h.initProject();
      try {
        h.wireGlobal('8.2.10');
        h.wireLocal('8.3.0');

        final code = await h.run(['--global-only']);

        expect(code, equals(ExitCode.success));
        final out = h.console.printed.join('\n');
        expect(out, contains('Global'));
        expect(out, isNot(contains('Local')));
      } finally {
        await h.cleanup();
      }
    });
  });
}
