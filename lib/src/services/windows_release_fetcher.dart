import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../domain/php_release.dart';
import 'release_fetcher.dart';
import 'release_parser.dart';

class WindowsReleaseFetcher implements IReleaseFetcher {
  static const String _apiUrl = PvmUrls.windowsReleasesApi;

  @override
  String get platformName => 'Windows';

  @override
  Future<List<PhpRelease>> fetchReleases() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode != 200) {
        return [];
      }
      if (response.body.isEmpty) {
        return [];
      }

      final parsed = ReleaseParser.parseWindowsReleases(response.body);
      if (parsed.isEmpty) {
        return [];
      }
      return parsed;
    } catch (e) {
      return [];
    }
  }
}
