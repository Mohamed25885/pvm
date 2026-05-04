import 'php_version.dart';

/// Helpers that produce consistent, user-facing messages about PHP versions.
///
/// Centralizes formatting so every command surfaces "version not installed"
/// (and similar diagnostics) with the same wording and hint.
class VersionDiagnostics {
  VersionDiagnostics._();

  /// Standard message displayed when a requested version is not installed.
  ///
  /// Example output:
  ///
  ///   Version 8.4 is not installed.
  ///   Installed versions: 8.3.0, 8.2.10, 7.4.33
  ///
  /// When [installed] is empty, the second line becomes:
  ///
  ///   No PHP versions installed.
  ///
  /// The order of [installed] is preserved verbatim so callers can decide
  /// whether to sort newest-first (preferred) or alphabetically.
  static String notInstalledMessage({
    required PhpVersion requested,
    required List<PhpVersion> installed,
  }) {
    final buffer = StringBuffer()
      ..write('Version ')
      ..write(requested.toString())
      ..writeln(' is not installed.');

    if (installed.isEmpty) {
      buffer.write('No PHP versions installed.');
    } else {
      buffer
        ..write('Installed versions: ')
        ..write(installed.map((v) => v.toString()).join(', '));
    }

    return buffer.toString();
  }
}
