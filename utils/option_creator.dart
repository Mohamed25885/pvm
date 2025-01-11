import 'dart:io';

import 'gitngore.dart';
import 'symlink_creator.dart';
import 'utils.dart';

class OptionCreator {
  static Future<({String from, String to})> createLocal(String version) async {
    final programDirectory = File(Platform.script.toFilePath()).parent;
    final gitIgnore = GitIgnore(programDirectory.path);

    if (await gitIgnore.checkExistence()) {
      print("Do you want to add .pvm to gitignore? (y\\n)");
      var answer = stdin.readLineSync();
      if (answer?.toLowerCase() == "y") {
        await gitIgnore.add(Utils.directoryName);
      }
    }

    return await SymlinkCreator.createSymLink(version, "${programDirectory.path}\\versions\\php${version}",
        "${Directory.current.path}\\${Utils.directoryName}");
  }

  static Future<({String from, String to})> createGlobal(String version) async {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final programDirectory = File(Platform.script.toFilePath()).parent;

    return await SymlinkCreator.createSymLink(
        version, "${programDirectory.path}\\versions\\php${version}", "$homeDir\\${Utils.directoryName}");
  }
}
