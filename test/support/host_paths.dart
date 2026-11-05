import 'dart:io';

/// Turn a Windows-style fixture path into an absolute path for the host OS,
/// so fake-filesystem tests mean the same thing on every OS (roadmap 2.8).
///
/// `C:\a\b` is returned unchanged on Windows and becomes `/a/b` elsewhere.
String hostPath(String windowsPath) {
  if (Platform.isWindows) return windowsPath;
  final noDrive = windowsPath.replaceFirst(RegExp(r'^[A-Za-z]:'), '');
  final posix = noDrive.replaceAll(r'\', '/');
  return posix.isEmpty ? '/' : posix;
}

/// The PHP binary name inside a version directory on the host OS.
String get hostPhpExe => Platform.isWindows ? 'php.exe' : 'php';
