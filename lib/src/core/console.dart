/// Abstraction for console I/O operations.
abstract class Console {
  void print(String message);
  void printError(String message);
  void printWarning(String message);
  String? readLine({String? prompt});
  bool get hasTerminal;
}

/// Yes/No confirmation prompt shared by all `Console` implementations.
///
/// Implemented as an extension so it stays out of the `Console` interface
/// (which is implemented by mocks/fakes) while still being callable as
/// `console.confirm(...)` everywhere.
extension ConsoleConfirm on Console {
  /// Prompt the user for a yes/no confirmation.
  ///
  /// Returns [defaultYes] when the console is non-interactive (no terminal)
  /// or when the user provides empty input. Otherwise returns `true` only
  /// when the input is `y` or `yes` (case-insensitive).
  ///
  /// The prompt suffix `(y/N)` / `(Y/n)` is appended automatically based on
  /// the [defaultYes] flag, so callers should pass the question without it
  /// (e.g. `"Delete PHP 8.2?"`).
  Future<bool> confirm(String prompt, {bool defaultYes = false}) async {
    if (!hasTerminal) return defaultYes;
    final suffix = defaultYes ? '(Y/n): ' : '(y/N): ';
    final input = readLine(prompt: '$prompt $suffix');
    if (input == null) return defaultYes;
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return defaultYes;
    return trimmed == 'y' || trimmed == 'yes';
  }
}
