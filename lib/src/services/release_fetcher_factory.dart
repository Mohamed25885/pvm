import 'package:pvm/src/core/platform_detector.dart';

import 'release_fetcher.dart';
import 'windows_release_fetcher.dart';
import 'linux_release_fetcher.dart';
import 'macos_release_fetcher.dart';

IReleaseFetcher createReleaseFetcher() {
  if (PlatformDetector.isWindows) return WindowsReleaseFetcher();
  if (PlatformDetector.isLinux) return LinuxReleaseFetcher();
  if (PlatformDetector.isMacOS) return MacosReleaseFetcher();
  throw const ReleaseFetcherException('Unsupported platform');
}
