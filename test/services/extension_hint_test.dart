import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pvm/src/commands/current_command.dart';
import 'package:pvm/src/commands/global_command.dart';
import 'package:pvm/src/commands/use_command.dart';
import 'package:pvm/src/core/active_version_resolver.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/core/symlink_inspector.dart';
import 'package:pvm/src/domain/install_record.dart';
import 'package:pvm/src/domain/php_version.dart';
import 'package:pvm/src/domain/version_registry.dart';
import 'package:pvm/src/services/extension_hint.dart';

import '../helpers.dart';
import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';

InstallRecord _record(String version, List<String> exts) => InstallRecord(
  version: version,
  sourceUrl: 'u',
  archiveSha256: 'a',
  verified: true,
  installedAt: DateTime.utc(2026),
  files: const {},
  extensions: [
    for (final e in exts)
      ExtensionEntry(
        name: e,
        version: '1',
        file: '$e.so',
        sha256: 's',
        verified: true,
      ),
  ],
);

InstalledSlot _slot(String version, List<String> exts) => InstalledSlot(
  PhpVersion.parse(version),
  '/v/$version',
  _record('$version.1', exts),
);

void main() {
  group('extensionHints', () {
    test('names an extension the target lacks', () {
      expect(
        extensionHints(_slot('8.3', []), [
          _slot('8.2', ['xdebug']),
        ]),
        [
          'xdebug is installed for 8.2 but not 8.3. Run: pvm ext install xdebug',
        ],
      );
    });

    test('no line when the target has it', () {
      expect(
        extensionHints(_slot('8.3', ['xdebug']), [
          _slot('8.2', ['xdebug']),
        ]),
        isEmpty,
      );
    });

    test('lowest version named, sorted by extension, no record ignored', () {
      final hints = extensionHints(_slot('8.4', []), [
        _slot('8.3', ['xdebug', 'apcu']),
        _slot('8.2', ['xdebug']),
        InstalledSlot(PhpVersion.parse('8.1'), '/v/8.1', null),
      ]);
      expect(hints, [
        'apcu is installed for 8.3 but not 8.4. Run: pvm ext install apcu',
        'xdebug is installed for 8.2 but not 8.4. Run: pvm ext install xdebug',
      ]);
    });
  });

  group('commands print the hint', () {
    late Directory tmp;
    late MockOSManager os;
    late MockConsole console;
    late String hint;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('pvm_hint_');
      os = MockOSManager()
        ..mockProgramDir = tmp.path
        ..mockHomeDir = p.join(tmp.path, 'home')
        ..mockCurrentDirectory = p.join(tmp.path, 'proj')
        ..mockLocalPath = p.join(tmp.path, 'proj', '.pvm')
        ..mockVersions = ['8.3', '8.2']
        ..symlinkSourceExistsOverride = true;
      Directory(os.mockCurrentDirectory!).createSync(recursive: true);
      os.setDirectoryExistsResult(os.phpVersionsPath, true);
      for (final v in ['8.2', '8.3']) {
        final dir = p.join(os.phpVersionsPath, v);
        os.setDirectoryExistsResult(dir, true);
        await _record('$v.1', v == '8.2' ? ['xdebug'] : []).writeTo(dir);
      }
      console = MockConsole();
      hint =
          'xdebug is installed for 8.2 but not 8.3. Run: pvm ext install xdebug';
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('use 8.3', () async {
      final runner = CommandRunner<int>('t', 't')
        ..addCommand(
          UseCommand(
            os,
            FakePhpVersionManager(console),
            FakeGitIgnoreService(os, console),
            MockVersionActivator(os),
            console,
          ),
        );
      final code = await runner.run(['use', '8.3']);
      expect(code, ExitCode.success);
      expect(console.printed, contains(hint));
    });

    test('global 8.3', () async {
      final runner = CommandRunner<int>('t', 't')
        ..addCommand(GlobalCommand(os, MockVersionActivator(os), console));
      expect(await runner.run(['global', '8.3']), ExitCode.success);
      expect(console.printed, contains(hint));
    });

    Future<int?> current(List<String> args) {
      os.symlinkTargets[p.join(os.mockHomeDir, '.pvm')] = p.join(
        os.phpVersionsPath,
        '8.3',
      );
      final runner = CommandRunner<int>('t', 't')
        ..addCommand(
          CurrentCommand(
            os,
            ActiveVersionResolver(SymLinkInspector(os)),
            console,
          ),
        );
      return runner.run(['current', ...args]);
    }

    test('current prints it, but not with --json', () async {
      expect(await current([]), ExitCode.success);
      expect(console.printed, contains(hint));

      console = MockConsole();
      expect(await current(['--json']), ExitCode.success);
      expect(console.printed.join('\n'), isNot(contains('xdebug')));
    });
  });
}
