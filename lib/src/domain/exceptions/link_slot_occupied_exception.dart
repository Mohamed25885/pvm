import 'pvm_exception.dart';

/// Thrown when the `.pvm` slot exists but is not a link PVM may replace.
///
/// PVM never deletes real files or directories at a link slot: they may hold
/// another tool's data (e.g. `%USERPROFILE%\.pvm`).
class LinkSlotOccupiedException extends PvmException {
  final String path;

  LinkSlotOccupiedException(this.path)
    : super(
        '"$path" already exists and is not a PVM link.\n'
        'PVM will not delete it. Move or rename it, then run the command again.',
      );
}
