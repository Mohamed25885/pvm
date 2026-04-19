import 'pvm_exception.dart';

/// Thrown when a requested version is not installed.
class VersionNotInstalledException extends PvmException {
  final String version; // Store as string to avoid circular dependency

  VersionNotInstalledException(dynamic version)
      : version = version.toString(),
        super('Version $version is not installed.');
}
