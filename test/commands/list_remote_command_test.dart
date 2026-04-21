import 'package:test/test.dart';


import '../../lib/src/services/php_downloader.dart';
import '../../lib/src/services/windows_release_fetcher.dart';
import '../../lib/src/commands/list_remote_command.dart';
import '../mocks/mock_console.dart';

void main() {
  group('ListRemoteCommand', () {
    test('argParser has arch option', () {
      final cmd = ListRemoteCommand(
        WindowsReleaseFetcher(),
        PhpDownloader(),
        MockConsole(),
      );

      final result = cmd.argParser.parse(['--arch', 'x64']);
      expect(result['arch'], 'x64');
    });

    test('argParser has type option', () {
      final cmd = ListRemoteCommand(
        WindowsReleaseFetcher(),
        PhpDownloader(),
        MockConsole(),
      );

      final result = cmd.argParser.parse(['--type', 'nts']);
      expect(result['type'], 'nts');
    });

    test('argParser accepts --type ts', () {
      final cmd = ListRemoteCommand(
        WindowsReleaseFetcher(),
        PhpDownloader(),
        MockConsole(),
      );

      final result = cmd.argParser.parse(['--type', 'ts']);
      expect(result['type'], 'ts');
    });

    test('command has correct name and description', () {
      final cmd = ListRemoteCommand(
        WindowsReleaseFetcher(),
        PhpDownloader(),
        MockConsole(),
      );

      expect(cmd.name, 'list-remote');
      expect(cmd.description, contains('PHP'));
    });
  });
}
