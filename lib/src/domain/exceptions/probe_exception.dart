import 'pvm_exception.dart';

/// Thrown when a version folder's own `php` cannot be probed.
class ProbeException extends PvmException {
  ProbeException(super.message);
}
