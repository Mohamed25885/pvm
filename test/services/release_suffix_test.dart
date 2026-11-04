import 'dart:convert';

import 'package:test/test.dart';

import 'package:pvm/src/domain/php_release.dart';
import 'package:pvm/src/services/release_parser.dart';
import 'package:pvm/src/services/windows_archive_index.dart';

void main() {
  test('releases.json rebuild suffix keeps the real patch (8.4.27-1)', () {
    // Shape of the live feed on 2026-11-04.
    final json = jsonEncode({
      '8.4': {
        'version': '8.4.27-1',
        'nts-vs17-x64': {
          'zip': {
            'path': 'php-8.4.27-1-nts-Win32-vs17-x64.zip',
            'size': '33.66MB',
            'sha256': 'dbae154a',
          },
        },
      },
      '7.4': {
        'version': '7.4.33',
        'nts-vc15-x64': {
          'zip': {'path': 'php-7.4.33-nts-Win32-vc15-x64.zip', 'sha256': 'x'},
        },
      },
    });

    final releases = ReleaseParser.parseWindowsReleases(json);
    final v84 = releases.firstWhere((r) => r.minor == 4 && r.major == 8);
    final v74 = releases.firstWhere((r) => r.major == 7);

    expect(v84.displayVersion, '8.4.27', reason: 'was 8.4.0 before the fix');
    expect(v84.downloadUrl, endsWith('php-8.4.27-1-nts-Win32-vs17-x64.zip'));
    expect(v74.displayVersion, '7.4.33');
  });

  test('archive listing: rebuilds parse and the newest rebuild wins', () {
    const html = '''
<a href="php-8.3.2-nts-Win32-vs16-x64.zip">x</a>
<a href="php-8.3.2-1-nts-Win32-vs16-x64.zip">x</a>
<a href="php-8.3.2-2-nts-Win32-vs16-x64.zip">x</a>
<a href="php-8.4.27-1-Win32-vs17-x86.zip">x</a>
''';

    final releases = WindowsArchiveIndex.parse(html);

    final nts = releases.where(
      (r) => r.buildType == BuildType.nts && r.displayVersion == '8.3.2',
    );
    expect(nts, hasLength(1));
    expect(
      nts.single.downloadUrl,
      endsWith('php-8.3.2-2-nts-Win32-vs16-x64.zip'),
    );
    final ts = releases.singleWhere((r) => r.minor == 4);
    expect(ts.displayVersion, '8.4.27');
    expect(ts.buildType, BuildType.ts);
    expect(ts.architecture, Architecture.x86);
  });
}
