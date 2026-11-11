import 'pvm_exception.dart';

/// Thrown when a slot cannot take an extension until it is reinstalled.
class SlotBrokenException extends PvmException {
  const SlotBrokenException(super.message);
}
