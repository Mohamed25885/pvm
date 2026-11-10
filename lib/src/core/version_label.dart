import '../domain/install_record.dart';
import '../domain/php_version.dart';

/// Installed versions display as `8.5 (8.5.22)`; `8.5` without a patch.
String versionLabel(PhpVersion slot, String? fullPatch) =>
    fullPatch == null ? slot.slot : '${slot.slot} ($fullPatch)';

/// [versionLabel] for the slot at [slotDir], reading its install record.
/// Without a record the version prints as given (a legacy `8.4.1` folder
/// keeps its patch).
Future<String> installedLabel(PhpVersion version, String slotDir) async {
  try {
    final record = await InstallRecord.readFrom(slotDir);
    return record == null
        ? version.toString()
        : versionLabel(version, record.version);
  } catch (_) {
    return version.toString(); // Unreadable: `pvm doctor` reports it.
  }
}
