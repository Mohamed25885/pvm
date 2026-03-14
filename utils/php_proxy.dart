import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'utils.dart';

class PhpProxy {
  static Process? _process;

  /// Starts the PHP process and sets up cleanup handlers.
  static Future<void> create(List<String> args) async {
    final phpPath = Utils.localPath;

    if (!(await Directory(phpPath).exists())) {
      throw Exception("No local version exists");
    }

    final phpExe = '$phpPath\\php.exe';
    if (!(await File(phpExe).exists())) {
      throw Exception("No PHP executable found");
    }

    // Start the PHP process
    _process = await Process.start(phpExe, args);

    // Listen to stdout and stderr
    _process!.stdout.transform(utf8.decoder).listen((data) {
      print(data);
    });

    _process!.stderr.transform(utf8.decoder).listen((data) {
      print(data);
    });

    // Forward stdin to the PHP process
    stdin.pipe(_process!.stdin);

    // Handle process exit
    _process!.exitCode.then((exitCode) {
      print("PHP process exited with code $exitCode");
      exit(exitCode);
    });

    // Set up cleanup handlers
    _setupCleanup();
  }

  /// Sets up cleanup handlers using a Windows message loop.
  static void _setupCleanup() {
    // Run the Windows message loop on the main thread
    final msg = calloc<MSG>();

    Timer.periodic(Duration(milliseconds: 100), (_) {
      // Use PeekMessage to check for messages
      if (PeekMessage(msg, 0, 0, 0, PM_REMOVE) != 0) {
        if (msg.ref.message == WM_CLOSE ||
            msg.ref.message == WM_DESTROY ||
            msg.ref.message == WM_QUIT) {
          print(
              "WM_CLOSE, WM_DESTROY, or WM_QUIT received. Terminating PHP process tree...");
          _killProcessTree();
          PostQuitMessage(0); // Exit the message loop
        }

        TranslateMessage(msg);
        DispatchMessage(msg);
      }
    });

    // Ensure the thread is cleaned up when the application exits
    ProcessSignal.sigint.watch().listen((_) async {
      await _killProcessTree();
      exit(0);
    });
  }

  /// Kills the PHP process and its child processes.
  static Future<void> _killProcessTree() async {
    if (_process != null) {
      await Process.run(
          'taskkill', ['/pid', _process!.pid.toString(), '/t', '/f']);
      _process = null;
    }
  }
}
