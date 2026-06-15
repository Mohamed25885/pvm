import 'package:path/path.dart' as p;

import 'constants.dart';

/// Resolved PVM installation paths from environment with legacy fallbacks.
class PvmPaths {
  final String pvmHome;
  final String versionsHome;

  const PvmPaths({required this.pvmHome, required this.versionsHome});

  factory PvmPaths.fromEnvironment(
    Map<String, String> env, {
    required String programDirectoryFallback,
  }) {
    final home =
        _nonEmptyEnv(env[PvmConstants.envPvmHome]) ?? programDirectoryFallback;
    final normalizedHome = p.normalize(home);
    final versions =
        _nonEmptyEnv(env[PvmConstants.envPvmVersionsHome]) ??
        p.join(normalizedHome, 'versions');
    return PvmPaths(
      pvmHome: normalizedHome,
      versionsHome: p.normalize(versions),
    );
  }

  static String? _nonEmptyEnv(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
