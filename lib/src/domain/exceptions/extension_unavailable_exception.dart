import 'pvm_exception.dart';

/// Thrown when PECL has no build of an extension for a slot.
class ExtensionUnavailableException extends PvmException {
  const ExtensionUnavailableException(super.message);
}
