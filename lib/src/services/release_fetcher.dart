import '../domain/php_release.dart';

abstract class IReleaseFetcher {
  Future<List<PhpRelease>> fetchReleases();
  String get platformName;
}

class ReleaseFetcherException implements Exception {
  final String message;
  const ReleaseFetcherException(this.message);
  @override
  String toString() => message;
}
