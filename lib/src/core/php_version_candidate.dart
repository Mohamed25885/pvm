/// Normalized PHP version candidate model for cross-platform version listing.
///
/// Different platforms output versions differently:
/// - Windows API: "8.4.1"
/// - apt: "php8.4"
/// - brew: "php@8.4"
class PhpVersionCandidate {
  final String version;
  final String rawName;
  final String source;
  final bool isInstalled;

  const PhpVersionCandidate({
    required this.version,
    required this.rawName,
    required this.source,
    this.isInstalled = false,
  });

  /// Normalize version string (e.g., "8.4.1" -> "8.4")
  static String normalize(String input) {
    // Remove common prefixes
    var normalized = input.replaceAll(RegExp(r'^php@?'), '');
    // If it has 3 parts (x.y.z), reduce to 2 parts (x.y)
    final parts = normalized.split('.');
    if (parts.length > 2) {
      return '${parts[0]}.${parts[1]}';
    }
    return normalized;
  }

  @override
  String toString() => 'PhpVersionCandidate($version from $source)';
}
