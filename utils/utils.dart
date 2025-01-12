import 'dart:io';
import 'package:path/path.dart' as p;

class Utils {
  static final directoryName = '.pvm';

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
