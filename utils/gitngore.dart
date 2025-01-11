import 'dart:convert';
import 'dart:io';

import 'utils.dart';

class GitIgnore {
  final Directory directory;

  GitIgnore(String dir) : this.directory = Directory(dir);

  Future<bool> checkExistence() async {
    if (await Directory(directory.path + "\\.git").exists()) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> add(String line) async {
    if (!(await checkExistence())) {
      return;
    }
    //add line to gitignore
    File file = File(directory.path + "\\.gitignore");
    if (file.existsSync()) {
      // Read the file line by line
      final lines = file.openRead().transform(utf8.decoder).transform(LineSplitter());

      // Process each line
      await for (final fLine in lines) {
        if (fLine == Utils.directoryName) {
          return;
        }
      }
      file.writeAsStringSync("\n"+line, mode: FileMode.append);
    } else {
      file.writeAsStringSync(line);
    }
  }
}
