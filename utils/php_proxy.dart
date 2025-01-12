import 'dart:convert';
import 'dart:io';

import 'utils.dart';

class PhpProxy {
  static Future<void> create(List<String> args) async {
    final phpPath = Utils.localPath;
    if (!(await Directory(phpPath).exists())) {
      throw Exception("No local version exists");
    }

    final phpExe = phpPath + "\\php.exe";
    if (!(await File(phpExe).exists())) {
      throw Exception("No php found");
    }

    final process = await Process.start(phpExe, args);

    process.stdout.transform(utf8.decoder).listen((data) {
      print(data);
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      print(data);
    });

    process.exitCode.then((exitCode) {
      exit(exitCode);
    });

    process.stdin.addStream(stdin);

    ProcessSignal.sigint.watch().listen((signal) async {
      await Process.run('taskkill', ['/pid', process.pid.toString(), '/t', '/f']);

      exit(0);
    });
  }
}
