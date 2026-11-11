import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';

import 'package:pvm/src/commands/list_command.dart';
import 'package:pvm/src/commands/php_command.dart';
import 'package:pvm/src/core/executable_resolver.dart';
import 'package:pvm/src/core/exit_codes.dart';
import 'package:pvm/src/services/php_executor.dart';

import '../mocks/mock_console.dart';
import '../mocks/mock_os_manager.dart';
import '../support/temp_dir.dart';

class _MissingPhpResolver implements IExecutableResolver {
  @override
  String get phpExecutableName => 'php.exe';

  @override
  Future<String> resolvePhpExecutable(String projectPath) async =>
      throw PhpExecutableNotFoundException('$projectPath/.pvm/php.exe');
}

void main() {
  test('B12: pvm list with no versions says so', () async {
    final os = MockOSManager()..mockVersions = [];
    final console = MockConsole();
    final runner = CommandRunner<int>('pvm', 't')
      ..addCommand(ListCommand(os, console));

    final code = await runner.run(['list']);

    expect(code, ExitCode.versionNotFound);
    expect(console.errors.join(), contains('No PHP versions installed'));
    expect(console.printed.join(), contains('pvm install'));
  });

  test('B14: pvm php without a local version matches README', () async {
    final temp = await Directory.systemTemp.createTemp('pvm_php_ux_');
    addTearDown(() => deleteTemp(temp));
    final os = MockOSManager()..mockCurrentDirectory = temp.path;
    final console = MockConsole();
    final executor = PhpExecutor(
      processManager: MockProcessManager(),
      osManager: os,
      executableResolver: _MissingPhpResolver(),
    );
    final runner = CommandRunner<int>('pvm', 't')
      ..addCommand(PhpCommand(executor, os, console));

    final code = await runner.run(['php', '-v']);

    expect(code, ExitCode.configurationError);
    expect(
      console.errors.join(),
      contains('No local version configured. Run "pvm use <version>" first.'),
    );
  });
}
