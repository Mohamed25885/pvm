import 'pvm_exception.dart';

/// Thrown when PHP does not list an extension PVM just enabled.
class ExtensionLoadException extends PvmException {
  final String ext;

  ExtensionLoadException(this.ext, String detail)
    : super('PHP did not load "$ext".${detail.isEmpty ? '' : '\n$detail'}');
}
