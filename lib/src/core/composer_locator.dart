import 'package:path/path.dart' as p;

import '../core/platform_constants.dart';
import '../core/os_manager.dart';

abstract class IComposerLocator {
  Future<String?> findComposer(Map<String, String> environment);
}

class ComposerLocator implements IComposerLocator {
  final PlatformConstants _platformConstants;
  final IOSManager _osManager;

  ComposerLocator({
    required PlatformConstants platformConstants,
    required IOSManager osManager,
  }) : _platformConstants = platformConstants,
       _osManager = osManager;

  @override
  Future<String?> findComposer(Map<String, String> environment) async {
    final pathEnv = environment['PATH'] ?? '';
    final separator = _platformConstants.pathSeparator;
    // Only absolute directories: an empty or relative segment (e.g. a
    // trailing ";") would resolve against the cwd and let a cloned repo
    // plant its own composer.phar (S5).
    final dirs = pathEnv
        .split(separator)
        .map((d) => d.replaceAll('"', '').trim())
        .where((d) => d.isNotEmpty && p.isAbsolute(d));

    final candidates = _platformConstants.composerCandidates;

    for (final dir in dirs) {
      for (final name in candidates) {
        final candidate = p.join(dir, name);
        if (await _osManager.fileExists(candidate)) {
          if (candidate.endsWith('.bat') || candidate.endsWith('.cmd')) {
            final phar = p.join(dir, _platformConstants.composerPharName);
            if (await _osManager.fileExists(phar)) {
              return phar;
            }
          }
          return candidate;
        }
      }
    }
    return null;
  }
}
