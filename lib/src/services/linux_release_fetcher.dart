import '../domain/php_release.dart';
import 'release_fetcher.dart';

class LinuxReleaseFetcher implements IReleaseFetcher {
  @override
  String get platformName => 'Linux';

  @override
  Future<List<PhpRelease>> fetchReleases() async {
    throw const ReleaseFetcherException(
        'Linux: Use your package manager (apt, dnf, yum) to install PHP');
  }
}
