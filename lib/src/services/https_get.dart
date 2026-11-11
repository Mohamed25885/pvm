import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../interfaces/i_installer.dart';

/// GET [url], following up to [maxRedirects] redirects by hand so that every
/// hop is checked to be `https` (R11). The caller checks the first URL against
/// its host allowlist; redirect targets are not added to it. Every hop sends
/// the PVM User-Agent.
///
/// Throws [DownloadException] for a non-https hop or too many redirects.
Future<http.StreamedResponse> httpsGet(
  http.Client client,
  Uri url, {
  int maxRedirects = 5,
}) async {
  for (var hop = 0; ; hop++) {
    if (url.scheme != 'https') {
      throw DownloadException('Refusing non-https URL: $url');
    }
    final request = http.Request('GET', url)
      ..followRedirects = false
      ..headers['User-Agent'] = PvmConstants.userAgent;
    final response = await client.send(request);
    if (!const {301, 302, 303, 307, 308}.contains(response.statusCode)) {
      return response;
    }
    await response.stream.drain<void>();
    final location = response.headers['location'];
    if (location == null) {
      throw DownloadException('Redirect without Location from $url');
    }
    if (hop >= maxRedirects) {
      throw DownloadException('Too many redirects (> $maxRedirects) from $url');
    }
    url = url.resolve(location);
  }
}
