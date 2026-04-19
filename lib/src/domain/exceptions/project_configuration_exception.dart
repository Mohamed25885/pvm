import 'pvm_exception.dart';

/// Thrown when .php-version contains invalid data.
class ProjectConfigurationException extends PvmException {
  ProjectConfigurationException(String message) : super(message);
}
