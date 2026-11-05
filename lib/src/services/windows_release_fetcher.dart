import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../domain/php_release.dart';
import 'release_fetcher.dart';
import 'release_parser.dart';

class WindowsReleaseFetcher implements IReleaseFetcher {
  static const String _apiUrl = PvmUrls.windowsReleasesApi;

  final http.Client? _client;

  WindowsReleaseFetcher({http.Client? client}) : _client = client;

  @override
  String get platformName => 'Windows';

  /// Throws [ReleaseFetcherException] when the release list cannot be
  /// fetched or parsed, so callers can tell "offline" from "no such version".
  @override
  Future<List<PhpRelease>> fetchReleases() async {
    final http.Response response;
    try {
      final uri = Uri.parse(_apiUrl);
      response = await (_client?.get(uri) ?? http.get(uri)).timeout(
        const Duration(seconds: 60),
      );
    } catch (e) {
      throw ReleaseFetcherException(
        'Could not reach the PHP release list ($_apiUrl): $e',
      );
    }
    if (response.statusCode != 200) {
      throw ReleaseFetcherException(
        'PHP release list returned HTTP ${response.statusCode} ($_apiUrl)',
      );
    }
    final parsed = response.body.isEmpty
        ? const <PhpRelease>[]
        : ReleaseParser.parseWindowsReleases(response.body);
    if (parsed.isEmpty) {
      throw const ReleaseFetcherException(
        'PHP release list was empty or could not be parsed',
      );
    }
    return parsed;
  }
}
