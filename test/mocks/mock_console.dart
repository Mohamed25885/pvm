import 'package:pvm/src/core/console.dart';

class MockConsole implements Console {
  final List<String> printed = [];
  final List<String> errors = [];
  final List<String> warnings = [];

  String? lastPrompt;
  final List<String> _inputs = [];

  // Mutable to simulate interactive/non-interactive mode
  bool _hasTerminal = true;
  @override
  bool get hasTerminal => _hasTerminal;
  set hasTerminal(bool value) => _hasTerminal = value;

  void simulateInput(String input) {
    _inputs.add(input);
  }

  @override
  void print(String message) {
    printed.add(message);
  }

  @override
  void printError(String message) {
    errors.add(message);
  }

  @override
  void printWarning(String message) {
    warnings.add(message);
  }

  @override
  String? readLine({String? prompt}) {
    lastPrompt = prompt;
    if (_inputs.isEmpty) return null;
    return _inputs.removeAt(0);
  }

  void reset() {
    printed.clear();
    errors.clear();
    warnings.clear();
    _inputs.clear();
    lastPrompt = null;
  }
}
