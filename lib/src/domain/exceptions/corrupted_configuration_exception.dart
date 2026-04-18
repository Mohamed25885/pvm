import 'pvm_exception.dart';

/// Thrown when PHP installation is corrupted (.pvm exists but php.exe missing).
class CorruptedConfigurationException extends PvmException {
  CorruptedConfigurationException(String message) : super(message);
}
