import '../core/platform_info.dart';
import '../domain/php_release.dart';
import 'release_fetcher.dart';
import 'windows_release_fetcher.dart';

IReleaseFetcher createReleaseFetcher([PlatformInfo? platform]) {
  final os = (platform ?? createPlatformInfo()).osType;
  return os == 'windows' ? WindowsReleaseFetcher() : _NoReleaseList(os);
}

/// Linux/macOS install from static-php.dev, which has no release list here.
class _NoReleaseList implements IReleaseFetcher {
  @override
  final String platformName;
  _NoReleaseList(this.platformName);

  @override
  Future<List<PhpRelease>> fetchReleases() async =>
      throw ReleaseFetcherException(
        'list-remote is not available on $platformName yet. '
        'Run: pvm install <X.Y>',
      );
}
