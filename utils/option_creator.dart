import 'dart:io';

import 'symlink_creator.dart';
import 'utils.dart';

class OptionCreator {
  static Future<({String from, String to})> createLocal(String version) async {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final programDirectory = File(Platform.script.toFilePath()).parent;

    return await SymlinkCreator.createSymLink(version, "${programDirectory.path}\\versions\\PHP${version}",
        "${Directory.current.path}\\${Utils.directoryName}");
  }

  static Future<({String from, String to})> createGlobal(String version) async {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final programDirectory = File(Platform.script.toFilePath()).parent;

    return await SymlinkCreator.createSymLink(
        version, "${programDirectory.path}\\versions\\PHP${version}", "$homeDir\\${Utils.directoryName}");
  }
}
