import '../core/console.dart';
import '../domain/php_release.dart';
import '../domain/php_version.dart';
import '../interfaces/i_installer.dart';
import '../interfaces/i_release_source.dart';
import 'release_fetcher.dart';
import 'windows_archive_index.dart';

/// windows.php.net: `releases.json` lists only the newest patch per minor;
/// an exact older patch is looked up in the archive (no checksums there).
class WindowsReleaseSource implements IReleaseSource {
  final IReleaseFetcher _fetcher;
  final WindowsArchiveIndex? _archiveIndex;
  final Console? _console;

  WindowsReleaseSource({
    required this._fetcher,
    this._archiveIndex,
    this._console,
  });

  @override
  String get name => 'windows.php.net';

  @override
  Future<PhpRelease> resolve(
    PhpVersion version, {
    required Architecture architecture,
    required BuildType buildType,
  }) async {
    final filter = PhpReleaseFilter(
      major: version.major,
      minor: version.minor,
      patch: version.patch,
      architecture: architecture,
      buildType: buildType,
    );

    // Throws ReleaseFetcherException when offline.
    _console?.print('Fetching available PHP versions...');
    final releases = await _fetcher.fetchReleases();
    var matching = releases.where(filter.matches).toList();

    if (matching.isEmpty && version.hasPatch && _archiveIndex != null) {
      _console?.print('Not in current releases; checking the archive...');
      final archived = await _archiveIndex.fetch();
      matching = archived.where(filter.matches).toList();
    }

    if (matching.isEmpty) {
      throw NoMatchingReleaseException(
        'No matching PHP release found for $version '
        '(${architecture.name}, ${buildType.name})',
      );
    }

    matching.sort((a, b) => (b.patch ?? 0).compareTo(a.patch ?? 0));
    final release = matching.first;
    // Re-validate: the version string came from remote data and becomes a
    // directory name (path traversal guard).
    PhpVersion.parse(release.displayVersion);
    return release;
  }
}
