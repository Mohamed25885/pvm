import 'pvm_exception.dart';

/// Thrown when no .php-version file exists or version not set.
class ProjectNotConfiguredException extends PvmException {
  ProjectNotConfiguredException([String? message])
      : super(message ??
            'No local PHP version configured.\nRun "pvm use <version>" first.');
}
