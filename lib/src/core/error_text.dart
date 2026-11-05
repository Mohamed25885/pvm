/// Human-readable text for an error, without Dart's `Exception: ` wrapper or
/// a repeated `Error: ` prefix, so CLI output never reads
/// "Error: Exception: Error: …" (D8).
String describeError(Object error) {
  var text = error.toString().trim();
  const prefixes = ['Exception: ', 'Error: ', 'FileSystemException: '];
  var changed = true;
  while (changed) {
    changed = false;
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trimLeft();
        changed = true;
      }
    }
  }
  return text;
}
