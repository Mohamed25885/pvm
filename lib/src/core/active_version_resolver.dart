import '../domain/php_version.dart';
import '../domain/project.dart';
import 'symlink_inspector.dart';

/// Which scope of version is currently effective.
enum VersionScope { global, local, none }

/// Result of resolving the effective PHP version for the current context.
class ActiveVersion {
  final VersionScope scope;
  final PhpVersion? version;
  final SymLinkInfo global;
  final SymLinkInfo local;

  const ActiveVersion({
    required this.scope,
    required this.version,
    required this.global,
    required this.local,
  });

  /// True when neither scope has a usable version.
  bool get isNone => scope == VersionScope.none;
}

/// Computes the effective PHP version using local-overrides-global precedence.
///
/// This is the canonical way for any command (current, doctor, exec, ...) to
/// answer "which PHP version is active right now?". By centralising it here
/// we guarantee identical precedence across the whole CLI.
class ActiveVersionResolver {
  final SymLinkInspector _inspector;

  ActiveVersionResolver(this._inspector);

  /// Resolve the effective version for [projectRoot] (defaults to walking
  /// up from CWD via [Project.findFromCurrentDirectory] when null).
  Future<ActiveVersion> resolve({String? projectRoot}) async {
    final globalInfo = await _inspector.inspectGlobal();

    final root = projectRoot ??
        (await Project.findFromCurrentDirectory()).rootDirectory.path;
    final localInfo = await _inspector.inspectLocal(root);

    // Local overrides global when local is OK.
    if (localInfo.status == SymLinkStatus.ok) {
      return ActiveVersion(
        scope: VersionScope.local,
        version: localInfo.version,
        global: globalInfo,
        local: localInfo,
      );
    }

    if (globalInfo.status == SymLinkStatus.ok) {
      return ActiveVersion(
        scope: VersionScope.global,
        version: globalInfo.version,
        global: globalInfo,
        local: localInfo,
      );
    }

    return ActiveVersion(
      scope: VersionScope.none,
      version: null,
      global: globalInfo,
      local: localInfo,
    );
  }
}
