import 'pvm_exception.dart';

/// Thrown when a version string has invalid format.
class InvalidVersionFormatException extends PvmException {
  final String invalidVersion;

  InvalidVersionFormatException(this.invalidVersion)
      : super(
          'Invalid version format: "$invalidVersion".\n'
          'Expected: x.y or x.y.z (e.g., 8.2, 8.2.1)',
        );
}
