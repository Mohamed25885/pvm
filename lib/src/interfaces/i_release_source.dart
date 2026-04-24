import '../core/php_version_candidate.dart';

/// Release source interface for fetching available PHP versions across platforms.
///
/// - Windows: fetches from PHP windows.php.net API
/// - Linux: queries apt-cache
/// - Mac: queries brew
abstract class IReleaseSource {
  /// Human-readable platform name (e.g., "Windows", "Linux (apt)", "macOS (brew)")
  String get platformName;

  /// Fetch available PHP versions for this platform.
  Future<List<PhpVersionCandidate>> fetchReleases();
}
