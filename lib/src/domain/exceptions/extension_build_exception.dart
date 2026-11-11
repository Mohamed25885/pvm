import 'pvm_exception.dart';

/// Thrown when building an extension (phpize, configure, make) fails.
class ExtensionBuildException extends PvmException {
  const ExtensionBuildException(super.message);
}
