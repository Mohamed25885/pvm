import 'dart:io' as io;
import '../core/console.dart';

/// Production implementation using dart:io.
class ConsoleIO implements Console {
  @override
  void print(String message) {
    io.stdout.writeln(message);
  }

  @override
  void printError(String message) {
    io.stderr.writeln('Error: $message');
  }

  @override
  void printWarning(String message) {
    io.stderr.writeln('Warning: $message');
  }

  @override
  String? readLine({String? prompt}) {
    if (prompt != null) {
      io.stdout.write(prompt);
    }
    return io.stdin.readLineSync();
  }

  @override
  bool get hasTerminal => io.stdout.hasTerminal;
}
