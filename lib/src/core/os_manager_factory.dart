import '../core/os_manager.dart';
import '../managers/io_os_manager.dart';
import 'link_manager.dart';
import 'platform_info.dart';

/// The real [IOSManager] for [platformInfo] (default: the host).
IOSManager createBaseOSManager([PlatformInfo? platformInfo]) {
  final platform = platformInfo ?? createPlatformInfo();
  return IoOSManager(
    platformInfo: platform,
    linkManager: createLinkManager(platform),
  );
}

/// Backward-compatible alias for tests and callers expecting a plain manager.
IOSManager createOSManager() => createBaseOSManager();
