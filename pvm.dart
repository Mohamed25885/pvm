import 'dart:io';

import 'package:args/args.dart';

import 'enums/options.dart';
import 'utils/option_creator.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    //..addCommand(Options.php.name)
    ..addOption(Options.version.name, abbr: 'v')
    ..addOption(Options.use.name);

  ArgResults argResults = parser.parse(arguments);
  final options = argResults;
  String? version = options.option(Options.version.name);
  String? useVersion = options.option(Options.use.name);

  if (version != null && useVersion != null) {
    print("can't use --version and --use together");
    exitCode = 1;
    return;
  }

  if (options.options.contains(Options.use.name) && useVersion == null) {
    print("select a version");
    exitCode = 1;
    return;
  }
  version ??= useVersion ?? "81";
  if (!['82', '81', '80'].contains(version)) {
    print("VERSION INCORRECT");

    return;
  }

  if (options.options.contains(Options.use.name)) {
    await await OptionCreator.createLocal(version);
  } else {
    var res;
    try {
      res = await OptionCreator.createGlobal(version);
      print('Symbolic link created successfully: ${res.to} -> ${res.from}');
    } catch (e) {
      exitCode = 1;
    }
    return;
  }
}
