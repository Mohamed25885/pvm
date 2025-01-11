import 'dart:io';

import 'package:args/args.dart';

import 'enums/options.dart';
import 'utils/option_creator.dart';
import 'utils/php_proxy.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    //..addCommand(Options.php.name)
    ..addOption(Options.version.name, abbr: 'v')
    ..addCommand(Options.use.name);
  List<String> phpArguments = [];

  if (arguments.contains(Options.php.name)) {
    final phpIndex = arguments.indexOf(Options.php.name);
    phpArguments = [...arguments].sublist(phpIndex + 1);
    arguments = [...arguments].sublist(0, phpIndex);
  }

  late ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print(e.toString());
    exitCode = 1;
    return;
  }

  final options = argResults;
  String? version = options.option(Options.version.name);
  String? useVersion = argResults.command?.rest.firstOrNull;

  if (version != null && useVersion != null) {
    print("can't use --version and --use together");
    exitCode = 1;
    return;
  }

  if (options.command?.name == Options.use.name && useVersion == null) {
    print("select a version");
    exitCode = 1;
    return;
  }
  version ??= useVersion ?? "81";
  if (!['82', '81', '80'].contains(version)) {
    print("VERSION INCORRECT");
    exitCode = 1;
    return;
  }

  if (options.command?.name == Options.use.name) {
    try {
      final res = await OptionCreator.createLocal(version);
      print('Local link created successfully: ${res.to} -> ${res.from}');
    } catch (e) {
      print(e.toString());
      exitCode = 1;
    }
  } else if (phpArguments.isNotEmpty) {
    await PhpProxy.create(phpArguments);
  } else {
    try {
      var res = await OptionCreator.createGlobal(version);
      print('Global link created successfully: ${res.to} -> ${res.from}');
    } catch (e) {
      print(e.toString());
      exitCode = 1;
    }
  }
  return;
}
