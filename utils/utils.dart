import 'dart:io';
import 'package:path/path.dart' as p;

class Utils {
  static final directoryName = '.pvm';
  
  static final localPath = "${Directory.current.path}\\${Utils.directoryName}";

  static Directory get programDirectory => File(Platform.script.toFilePath()).parent;   

  static String get phpVersionsPath {
    return "${Utils.programDirectory.path}\\versions";
  }  

  static List<String> get  availableVersions {
    return Utils._getDirectories("${Directory.current.path}\\versions", recursive: false);
  }

  static List<String> _getDirectories(String path, {bool recursive = false}) {
    return Directory(path)
        .listSync(recursive: recursive)
        .where((FileSystemEntity entity) => entity is Directory)
        .map((FileSystemEntity entity) => p.basename(entity.path))
        .toList();
  }
}
