/// Classifies Windows symlink permission failures.
bool isPermissionDenied(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('access is denied') ||
      message.contains('access denied') ||
      message.contains('privilege is not held') ||
      message.contains('error 1314') ||
      message.contains('elevation required');
}
