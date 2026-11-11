import '../core/console.dart';
import '../domain/php_version.dart';
import '../domain/version_registry.dart';

/// One line per extension installed in another slot but not in [target].
/// When several slots have it, the lowest version is named. Sorted by name.
List<String> extensionHints(InstalledSlot target, List<InstalledSlot> others) {
  final have = {for (final e in target.record?.extensions ?? []) e.name};
  final from = <String, InstalledSlot>{};
  final sorted = [...others]..sort((a, b) => a.version.compareTo(b.version));
  for (final slot in sorted) {
    for (final e in slot.record?.extensions ?? []) {
      if (!have.contains(e.name)) from.putIfAbsent(e.name, () => slot);
    }
  }
  return [
    for (final name in from.keys.toList()..sort())
      '$name is installed for ${from[name]!.version.slot} but not '
          '${target.version.slot}. Run: pvm ext install $name',
  ];
}

/// Prints the hints for the slot at [targetPath]; never throws or changes the
/// caller's exit code.
Future<void> printExtensionHints(
  Console console,
  VersionRegistry registry,
  String targetPath,
) async {
  try {
    final slots = await registry.installedSlots();
    final target = slots.where((s) => s.path == targetPath).firstOrNull;
    if (target == null) return;
    extensionHints(
      target,
      slots.where((s) => s.path != targetPath).toList(),
    ).forEach(console.print);
  } catch (_) {
    // A hint is a courtesy.
  }
}
