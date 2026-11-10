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
/// Only legacy full-patch folders that `SlotMigration` refused to merge can
/// produce this: migrated slots hold one version per minor.
final class AmbiguousInstalledVersion extends InstalledVersionResolveResult {
  final List<PhpVersion> candidates;

  AmbiguousInstalledVersion(this.candidates);
}

/// Resolves a request against installed slots: an exact match first, then the
/// slot of the requested minor (a full patch such as a `.pvmrc` `8.2.28` maps
/// to the `8.2` slot).
class InstalledVersionResolver {
  InstalledVersionResolver._();

  static InstalledVersionResolveResult resolve(
    PhpVersion requested,
    List<PhpVersion> installed,
  ) {
    if (installed.contains(requested)) {
      return ResolvedInstalledVersion(requested);
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
