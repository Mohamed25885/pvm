import 'dart:io';

import 'release_fetcher.dart';
import 'windows_release_fetcher.dart';
import 'linux_release_fetcher.dart';
import 'macos_release_fetcher.dart';

IReleaseFetcher createReleaseFetcher() {
  if (Platform.isWindows) return WindowsReleaseFetcher();
  if (Platform.isLinux) return LinuxReleaseFetcher();
  if (Platform.isMacOS) return MacosReleaseFetcher();
  throw const ReleaseFetcherException('Unsupported platform');
}
