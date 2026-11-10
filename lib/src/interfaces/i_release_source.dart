import '../domain/php_release.dart';
import '../domain/php_version.dart';

/// Where PHP builds come from (roadmap 2.6): turns a requested version into
/// the one concrete, downloadable build to install.
///
/// Windows: windows.php.net `releases.json`, then the archive for older
/// patches. Phase 3 adds static builds for Linux/macOS.
abstract interface class IReleaseSource {
  /// Human-readable name for messages (e.g. `windows.php.net`).
  String get name;

  /// The best build matching [version] (newest patch when [version] has
  /// none).
  ///
  /// Throws `NoMatchingReleaseException` when nothing matches and
  /// `ReleaseFetcherException` when the source cannot be reached, so a
  /// network error is never reported as "no such version".
  Future<PhpRelease> resolve(
    PhpVersion version, {
    required Architecture architecture,
    required BuildType buildType,
  });
}
