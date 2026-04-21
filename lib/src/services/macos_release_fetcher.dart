import '../domain/php_release.dart';
import 'release_fetcher.dart';

class MacosReleaseFetcher implements IReleaseFetcher {
  @override
  String get platformName => 'macOS';

  @override
  Future<List<PhpRelease>> fetchReleases() async {
    throw const ReleaseFetcherException(
        'macOS: Use Homebrew - brew install php');
  }
}
