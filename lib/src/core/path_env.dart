import 'package:path/path.dart' as p;

/// Returns a copy of [env] with [dir] as the first `PATH` entry.
///
/// Windows environment keys are case-insensitive (`Path` vs `PATH`); the
/// existing key's spelling is reused so the child does not end up with two
/// PATH variables. An existing occurrence of [dir] is moved to the front.
Map<String, String> prependToPath(
  Map<String, String> env,
  String dir, {
  required String separator,
  bool caseInsensitiveKeys = false,
}) {
  final result = Map<String, String>.from(env);
  final key = result.keys.firstWhere(
    (k) => caseInsensitiveKeys ? k.toUpperCase() == 'PATH' : k == 'PATH',
    orElse: () => 'PATH',
  );
  final normalized = p.normalize(dir);
  String keyOf(String s) => caseInsensitiveKeys
      ? p.normalize(s.trim()).toLowerCase()
      : p.normalize(s.trim());
  final rest = (result[key] ?? '')
      .split(separator)
      .where((s) => s.trim().isNotEmpty && keyOf(s) != keyOf(normalized));
  result[key] = [dir, ...rest].join(separator);
  return result;
}
