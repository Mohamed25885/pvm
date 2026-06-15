import 'pvm_exception.dart';

/// Thrown when `.pvmrc` contains invalid data.
class ProjectConfigurationException extends PvmException {
  ProjectConfigurationException(String message) : super(message);
}
