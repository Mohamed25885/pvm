import 'dart:io';

import 'package:args/args.dart';

import 'enums/options.dart';
import 'utils/option_creator.dart';
import 'utils/php_proxy.dart';
import 'utils/utils.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(Options.help.name, abbr: "h")
    ..addCommand(Options.list.name)
    ..addCommand(Options.global.name)
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

  String? version = argResults.command?.rest.firstOrNull;
  String? commandName = argResults.command?.name;

  if (argResults.flag(Options.help.name)) {
    print(
        "'use' to create local version, 'global' to create global version, 'php' to start proxy, 'list' to list available versions");
    return;
  }

  List<String> availableVersions = await Utils.availableVersions;

  version ??= version ?? availableVersions.firstOrNull;
  if (!availableVersions.contains(version)) {
    print("VERSION INCORRECT");
    exitCode = 1;
    return;
  }
  if (version == null) {
    print("No versions provided");
    exitCode = 1;
    return;
  }

  if (commandName == Options.use.name) {
    try {
      final res = await OptionCreator.createLocal(version);
      print('Local link created successfully: ${res.to} -> ${res.from}');
    } catch (e) {
      print(e.toString());
      exitCode = 1;
    }
  } else if (commandName == Options.list.name) {
    print(availableVersions.join('\t'));
  } else if (phpArguments.isNotEmpty) {
    await PhpProxy.create(phpArguments);
  } else if (commandName == Options.global.name) {
    try {
      var res = await OptionCreator.createGlobal(version);
      print('Global link created successfully: ${res.to} -> ${res.from}');
    } catch (e) {
      print(e.toString());
      exitCode = 1;
    }
  } else {
    print("Use one of the options");
    exitCode = 1;
  }
  return;
}
