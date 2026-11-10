import '../core/platform_info.dart';
import 'release_fetcher.dart';
import 'windows_release_fetcher.dart';
import 'linux_release_fetcher.dart';
import 'macos_release_fetcher.dart';

IReleaseFetcher createReleaseFetcher([PlatformInfo? platform]) {
  switch ((platform ?? createPlatformInfo()).osType) {
    case 'windows':
      return WindowsReleaseFetcher();
    case 'linux':
      return LinuxReleaseFetcher();
    case 'macos':
      return MacosReleaseFetcher();
    default:
      throw const ReleaseFetcherException('Unsupported platform');
  }
}
