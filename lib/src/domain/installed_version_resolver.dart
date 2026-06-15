import 'php_version.dart';

/// Outcome of resolving a user-requested version against installed versions.
sealed class InstalledVersionResolveResult {}

/// A single unambiguous installed version matches the request.
final class ResolvedInstalledVersion extends InstalledVersionResolveResult {
  final PhpVersion version;

  ResolvedInstalledVersion(this.version);
}

/// No installed version matches the request.
final class NotFoundInstalledVersion extends InstalledVersionResolveResult {}

/// Multiple installed versions share the requested major.minor; patch required.
final class AmbiguousInstalledVersion extends InstalledVersionResolveResult {
  final List<PhpVersion> candidates;

  AmbiguousInstalledVersion(this.candidates);
}

/// Resolves shorthand `major.minor` against installed PHP versions.
class InstalledVersionResolver {
  InstalledVersionResolver._();

  static InstalledVersionResolveResult resolve(
    PhpVersion requested,
    List<PhpVersion> installed,
  ) {
    if (installed.contains(requested)) {
      return ResolvedInstalledVersion(requested);
    }

    if (requested.hasPatch) {
      return NotFoundInstalledVersion();
    }

    final candidates = installed
        .where((v) => v.major == requested.major && v.minor == requested.minor)
        .toList();

    if (candidates.isEmpty) {
      return NotFoundInstalledVersion();
    }

    if (candidates.length == 1) {
      return ResolvedInstalledVersion(candidates.first);
    }

    candidates.sort((a, b) => b.compareTo(a));
    return AmbiguousInstalledVersion(List.unmodifiable(candidates));
  }
}
