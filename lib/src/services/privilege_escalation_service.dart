import '../core/console.dart';
import '../core/permission_error.dart';
import '../interfaces/i_privilege_escalator.dart';

/// Prompts for elevation and retries symlink operations once.
class PrivilegeEscalationService {
  final Console _console;
  final IPrivilegeEscalator _escalator;

  PrivilegeEscalationService(this._console, this._escalator);

  /// Runs [action]; on permission denial prompts once and retries after elevation.
  Future<T> runWithElevationRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (!isPermissionDenied(e)) rethrow;
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
