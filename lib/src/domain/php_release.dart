enum Architecture { x64, x86 }

enum BuildType { ts, nts }

class PhpRelease {
  final String versionString;
  final int major;
  final int minor;
  final int? patch;
  final Architecture architecture;
  final BuildType buildType;
  final String downloadUrl;
  final String sha256;
  final int sizeBytes;
  final DateTime lastModified;

  const PhpRelease({
    required this.versionString,
    required this.major,
    required this.minor,
    this.patch,
    required this.architecture,
    required this.buildType,
    required this.downloadUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.lastModified,
  });

  String get displayVersion =>
      patch != null ? '$major.$minor.$patch' : '$major.$minor';

  String get sizeFormatted {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
  }

  static Architecture? architectureFromString(String s) {
    final lower = s.toLowerCase();
    if (lower == 'x64' || lower == 'x86_64' || lower == 'amd64') {
      return Architecture.x64;
    }
    if (lower == 'x86' || lower == 'i386' || lower == 'i686') {
      return Architecture.x86;
    }
    return null;
  }

  static BuildType? buildTypeFromString(String s) {
    final lower = s.toLowerCase();
    if (lower == 'ts' || lower == 'threadsafe') {
      return BuildType.ts;
    }
    if (lower == 'nts') {
      return BuildType.nts;
    }
    return null;
  }
}

class PhpReleaseFilter {
  final int? major;
  final int? minor;
  final int? patch;
  final Architecture? architecture;
  final BuildType? buildType;

  const PhpReleaseFilter({
    this.major,
    this.minor,
    this.patch,
    this.architecture,
    this.buildType,
  });

  bool matches(PhpRelease release) {
    if (major != null && release.major != major) return false;
    if (minor != null && release.minor != minor) return false;
    if (patch != null && release.patch != patch) return false;
    if (architecture != null && release.architecture != architecture)
      return false;
    if (buildType != null && release.buildType != buildType) return false;
    return true;
  }
}
