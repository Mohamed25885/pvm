import 'package:meta/meta.dart';
import '../core/constants.dart';
import 'exceptions.dart';

/// Value object representing a PHP version (immutable).
@immutable
class PhpVersion implements Comparable<PhpVersion> {
  final int major;
  final int minor;
  final int? patch;

  const PhpVersion(this.major, this.minor, [this.patch]);

  /// Parse version string like "8.2" or "8.2.1".
  /// Throws [InvalidVersionFormatException] if format is invalid.
  factory PhpVersion.parse(String versionString) {
    final pattern = RegExp(PvmConstants.versionPattern);
    final match = pattern.firstMatch(versionString.trim());

    if (match == null) {
      throw InvalidVersionFormatException(versionString);
    }

    final major = match.group(1);
    final minor = match.group(2);
    if (major == null || minor == null) {
      throw InvalidVersionFormatException(versionString);
    }
    final patch = match.group(3);
    return PhpVersion(
      int.parse(major),
      int.parse(minor),
      patch != null ? int.parse(patch) : null,
    );
  }

  bool get hasPatch => patch != null;

  /// Check if this version is at least the specified version.
  bool isAtLeast(int major, [int? minor, int? patch]) {
    if (this.major > major) return true;
    if (this.major < major) return false;

    if (minor == null) return true;
    if (this.minor > minor) return true;
    if (this.minor < minor) return false;

    if (patch == null) return true;
    return (this.patch ?? 0) >= patch;
  }

  @override
  int compareTo(PhpVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return (patch ?? 0).compareTo(other.patch ?? 0);
  }

  @override
  bool operator ==(Object other) =>
      other is PhpVersion &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => hasPatch ? '$major.$minor.$patch' : '$major.$minor';

  /// Always returns short format "8.2".
  String toShortString() => '$major.$minor';
}
