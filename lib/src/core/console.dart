/// Abstraction for console I/O operations.
abstract class Console {
  void print(String message);
  void printError(String message);
  void printWarning(String message);
  String? readLine({String? prompt});
  bool get hasTerminal;
}
