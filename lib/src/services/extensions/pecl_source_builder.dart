import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/console.dart';
import '../../core/platform_info.dart';
import '../../core/process_manager.dart';
import '../../domain/install_record.dart';
import '../../domain/php_version.dart';
import '../../domain/version_registry.dart';
import '../build_tools.dart';
import '../slot_ini.dart';
import 'extension_artifact.dart';
import 'pecl_download.dart';

export 'pecl_download.dart'
    show ExtensionUnavailableException, SlotBrokenException;

/// Linux/macOS: builds a PECL extension against one slot with that slot's
/// own phpize and php-config, then installs it through [ExtensionInstallTxn].
class PeclSourceBuilder {
  final PlatformInfo _platform;
  final Console _console;
  final IProcessManager _pm;
  final BuildTools _tools;
  final PeclDownloads _downloads;

  /// `make -j<jobs>`.
  final int jobs;

  PeclSourceBuilder({
    required this._platform,
    required this._console,
    required IProcessManager processManager,
    required BuildTools buildTools,
    required this.jobs,
    required http.Client client,
    Duration retryDelay = const Duration(seconds: 1),
  }) : _pm = processManager,
       _tools = buildTools,
       _downloads = PeclDownloads(_platform, _console, client, retryDelay);

  /// Builds and installs the latest stable [ext]. The caller records the
  /// returned entry in the slot record.
  Future<ExtensionEntry> install(String ext, InstalledSlot slot) async {
    ExtensionArtifact.validateName(ext);
    final x = slot.version.slot;
    final broken = SlotBrokenException(
      'Slot $x is broken (bin/php missing); reinstall it',
    );
    final php = p.join(slot.path, 'bin', 'php');
    final record = slot.record;
    final phpConfig = record?.phpConfig;
    if (!await File(php).exists() ||
        record == null ||
        phpConfig == null ||
        !await File(phpConfig).exists()) {
      throw broken;
    }
    // Same name form as php-config (php-config8.4 -> phpize8.4).
    final phpize = p.join(
      p.dirname(phpConfig),
      p.basename(phpConfig).replaceFirst('php-config', 'phpize'),
    );
    if (!await File(phpize).exists()) throw broken;

    final r = await _pm.runCaptured(
      ProcessSpec(executable: phpConfig, arguments: ['--prefix']),
    );
    final prefix = r.stdout.trim();
    if (r.exitCode != 0 ||
        !p.equals(p.normalize(prefix), p.normalize(slot.path))) {
      throw SlotBrokenException(
        'Slot $x was built for $prefix; reinstall it with '
        'pvm install $x --from-source --force',
      );
    }

    // The slot's phpize was checked above; `command -v phpize` could find
    // another PHP's.
    await _tools.require([
      'cc',
      'make',
      'autoconf',
      'pkg-config',
      if (ext == 'grpc') 'c++',
    ]);

    final tmp = await Directory.systemTemp.createTemp('pvm-pecl-');
    try {
      final ver = await _downloads.stableVersion(ext, tmp.path);
      _console.print('Downloading $ext $ver...');
      final tgz = await _downloads.get(
        'https://pecl.php.net/get/$ext-$ver.tgz',
        tmp.path,
      );
      final sha = await _downloads.sha256Of(tgz);
      final untar = await _pm.runCaptured(
        ProcessSpec(
          executable: 'tar',
          arguments: ['-xzf', tgz.path, '-C', tmp.path],
        ),
      );
      if (untar.exitCode != 0) {
        throw Exception('tar failed: ${untar.stderr.trim()}');
      }
      final src = p.join(tmp.path, '$ext-$ver');

      if (ext == 'grpc') {
        _console.print('grpc is a long C++ build (can take 30+ minutes).');
      }
      _console.print('Building $ext $ver for PHP $x...');
      final env = await _tools.buildEnvironment();
      await _step(phpize, [], src, env);
      await _step(
        p.join(src, 'configure'),
        ['--with-php-config=$phpConfig'],
        src,
        env,
      );
      await _step('make', ['-j$jobs'], src, env);

      final built = File(p.join(src, 'modules', '$ext.so'));
      if (!await built.exists()) {
        throw Exception('The build did not produce modules/$ext.so');
      }
      await ExtensionInstallTxn(_pm, php).commit(
        built,
        record.extensionDir,
        SlotIni(slot.path, record, _platform),
        ext,
      );
      return ExtensionEntry(
        name: ext,
        version: ver,
        file: extensionFileName(_platform, ext),
        sha256: sha,
        verified: false,
      );
    } finally {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _step(
    String exe,
    List<String> args,
    String cwd,
    Map<String, String>? env,
  ) async {
    final code = await _pm.runInteractive(
      ProcessSpec(
        executable: exe,
        arguments: args,
        workingDirectory: cwd,
        environment: env,
      ),
    );
    if (code != 0) {
      throw Exception('${p.basename(exe)} failed (exit $code)');
    }
  }

  void dispose() => _downloads.dispose();
}
