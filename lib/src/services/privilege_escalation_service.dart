import '../core/console.dart';
import '../core/permission_error.dart';
import '../interfaces/i_privilege_escalator.dart';

/// Thrown when a link cannot be created for lack of privilege and PVM cannot
/// elevate by itself. Carries actionable guidance instead of the raw OS error.
class LinkPermissionException implements Exception {
  final Object cause;
  const LinkPermissionException(this.cause);

  @override
  String toString() =>
      'Windows refused to create the link ($cause).\n'
      'Fix: enable Developer Mode (Settings > System > For developers), '
      'or run this command from an Administrator terminal.';
}

/// Prompts for elevation and retries symlink operations once.
class PrivilegeEscalationService {
  final Console _console;
  final IPrivilegeEscalator _escalator;

  PrivilegeEscalationService(this._console, this._escalator);

  /// Runs [action]; on permission denial prompts once and retries after
  /// elevation — but only when elevation can actually work (S11).
  Future<T> runWithElevationRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (!isPermissionDenied(e)) rethrow;
      if (!_escalator.canElevate) throw LinkPermissionException(e);
      if (!_console.hasTerminal) rethrow;

      final approved = await _console.confirm(
        'Creating a symbolic link requires administrator privileges. '
        'Elevate and retry?',
        defaultYes: false,
      );
      if (!approved) rethrow;

      final elevated = await _escalator.requestElevation();
      if (!elevated) rethrow;

      return await action();
    }
  }
}
