import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/console.dart';
import '../core/php_layout.dart';
import '../core/platform_info.dart';
import '../core/process_manager.dart';
import '../domain/install_record.dart';
import '../domain/php_release.dart';
import '../domain/php_version.dart';
import '../interfaces/i_installer.dart';
import '../services/build_tools.dart';
import '../services/folder_probe.dart';
import '../services/https_get.dart';
import '../services/installation/artifact_installer.dart';
import '../services/release_fetcher.dart';

// The flags of the measured WSL build (spec 2026-11-10-linux-macos-php-and-extensions-design.md, "Proven so far").
const sourceConfigureFlags = [
  '--disable-cgi',
  '--enable-bcmath',
  '--enable-mbstring',
  '--enable-intl',
  '--enable-sockets',
  '--enable-pcntl',
  '--enable-exif',
  '--enable-soap',
  '--enable-gd',
  '--with-freetype',
  '--with-jpeg',
  '--with-webp',
  '--with-zip',
  '--with-zlib',
  '--with-curl',
  '--with-openssl',
  '--with-sodium',
  '--with-pdo-mysql',
  '--with-mysqli',
  '--with-pdo-pgsql',
  '--with-pgsql',
  '--with-pdo-sqlite',
  '--with-readline',
  '--with-gmp',
  '--with-xsl',
  '--enable-opcache',
];

const _buildTools = [
  'cc',
  'make',
  'autoconf',
  'bison',
  're2c',
  'pkg-config',
  'tar',
];

/// pkg-config modules of the key dev packages (a missing one means the
/// headers are not installed).
const _devModules = [
  'libxml-2.0',
  'sqlite3',
  'openssl',
  'libcurl',
  'oniguruma',
  'libzip',
  'icu-uc',
];

/// Linux/macOS: builds PHP from the verified php.net tarball into the slot
/// with phpize/php-config ([SlotKind.source]). The system's own compiler and
/// libraries are used; missing ones are reported, never installed.
class SourceBuildInstaller implements IInstaller {
  final ArtifactInstaller _artifacts;
  final IProcessManager _pm;
  final BuildTools _tools;
  final Console _console;
  final http.Client _client;
  final PlatformInfo _platform;

  /// `make -j<jobs>`.
  final int jobs;

  SourceBuildInstaller({
    required String versionsPath,
    required this._platform,
    required this._console,
    required IProcessManager processManager,
    required BuildTools buildTools,
    required this.jobs,
    required this._client,
    FolderProbe? probe,
    Duration retryDelay = const Duration(seconds: 1),
  }) : _pm = processManager,
       _tools = buildTools,
       _artifacts = ArtifactInstaller(
         versionsPath: versionsPath,
         layout: PhpLayout.unix,
         platform: _platform,
         allowedHosts: const ['www.php.net'],
         console: _console,
         probe: probe,
         client: _client,
         retryDelay: retryDelay,
       );

  @override
  String get versionsPath => _artifacts.versionsPath;

  @override
  String get installationType => 'source build';

  @override
  Future<bool> isInstalled(String version) => _artifacts.isInstalled(version);

  @override
  Future<InstallResult> install(
    String version, {
    InstallOptions? options,
  }) async {
    final release = await _resolve(PhpVersion.parse(version));
    final resolved = release.versionString;
    if (await _artifacts.slotHolds(
          resolved,
          SlotKind.source,
          replace: options?.update != null,
          force: options?.force ?? false,
        ) &&
        !(options?.force ?? false)) {
      return InstallResult(resolved, alreadyInstalled: true);
    }
    final verified = release.sha256.isNotEmpty;
    if (!verified && !(options?.allowUnverified ?? false)) {
      throw UnverifiedReleaseException(resolved);
    }
    await _tools.require(_buildTools, devPackages: _devModules);

    final slot = PhpVersion.parse(resolved).slot;
    final prefix = p.join(versionsPath, slot);
    final staging = await _artifacts.stagingFor(slot);
    // Outside versions/: a killed build never looks like a slot.
    final buildDir = await Directory.systemTemp.createTemp('pvm-build-');
    try {
      _console.print('Downloading PHP $resolved...');
      final tarball = await _artifacts.download(release, buildDir.path);
      final actualSha = await _artifacts.sha256Of(tarball);
      if (verified) {
        _console.print('Verifying SHA256...');
        if (actualSha != release.sha256) {
          throw Exception('SHA256 verification failed');
        }
      } else {
        _console.printWarning(
          'No published checksum for PHP $resolved; building '
          'unverified (sha256 $actualSha recorded).',
        );
      }

      final untar = await _pm.runCaptured(
        ProcessSpec(
          executable: 'tar',
          arguments: ['-xJf', tarball.path, '-C', buildDir.path],
        ),
      );
      if (untar.exitCode != 0) {
        throw Exception('tar failed: ${untar.stderr.trim()}');
      }
      final src = p.join(buildDir.path, 'php-$resolved');

      _console.print('Building PHP $resolved from source (about 5 minutes)...');
      final env = await _tools.buildEnvironment();
      // Output streams to the terminal (inherited stdio).
      await _step(
        p.join(src, 'configure'),
        [
          '--prefix=$prefix',
          '--with-config-file-path=${p.join(prefix, 'etc')}',
          '--with-config-file-scan-dir=${p.join(prefix, 'etc', 'conf.d')}',
          ...sourceConfigureFlags,
        ],
        src,
        env,
      );
      await _step('make', ['-j$jobs'], src, env);
      await _step(
        'make',
        ['install', 'INSTALL_ROOT=${staging.path}'],
        src,
        env,
      );

      // make install writes <INSTALL_ROOT><prefix>/...
      final tree = p.join(
        staging.path,
        p.relative(prefix, from: p.rootPrefix(prefix)),
      );
      await _artifacts.commit(
        tree,
        release,
        resolved,
        kind: SlotKind.source,
        archiveSha256: actualSha,
        verified: verified,
        beforeSwap: options?.update,
      );
    } finally {
      for (final dir in [staging, buildDir]) {
        try {
          if (await dir.exists()) await dir.delete(recursive: true);
        } catch (_) {}
      }
    }
    return InstallResult(resolved);
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
      throw Exception('${p.basename(exe)} ${args.first} failed (exit $code)');
    }
  }

  /// The newest patch of an X.Y (or the exact X.Y.Z) from php.net, with the
  /// sha256 of its `.tar.xz` ('' when php.net publishes none).
  Future<PhpRelease> _resolve(PhpVersion version) async {
    final url = 'https://www.php.net/releases/index.php?json&version=$version';
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await httpsGet(_client, Uri.parse(url)),
      ).timeout(const Duration(seconds: 60));
    } catch (e) {
      throw ReleaseFetcherException('Could not reach $url: $e');
    }
    if (response.statusCode != 200) {
      throw ReleaseFetcherException(
        '$url returned HTTP ${response.statusCode}',
      );
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ReleaseFetcherException('Unreadable release data from $url');
    }
    final v = json['version'];
    // Remote data becomes a directory name: re-validate (path traversal).
    PhpVersion? parsed;
    try {
      parsed = PhpVersion.parse(v as String);
    } catch (_) {}
    if (parsed == null ||
        !parsed.hasPatch ||
        parsed.slot != version.slot ||
        (version.hasPatch && parsed.patch != version.patch)) {
      throw NoMatchingReleaseException('php.net has no release $version');
    }
    final resolved = parsed.toString();
    final file = 'php-$resolved.tar.xz';
    final entry = (json['source'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((s) => s['filename'] == file)
        .firstOrNull;
    final sha = (entry?['sha256'] as String? ?? '').trim().toLowerCase();
    if (sha.isNotEmpty && !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw ReleaseFetcherException('Malformed sha256 for $file from $url');
    }
    return PhpRelease(
      versionString: resolved,
      major: parsed.major,
      minor: parsed.minor,
      patch: parsed.patch!,
      architecture:
          PhpRelease.architectureFromString(_platform.hostArch) ??
          Architecture.x64,
      buildType: BuildType.nts,
      downloadUrl: 'https://www.php.net/distributions/$file',
      sha256: sha,
      sizeBytes: 0,
      lastModified: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Future<File> downloadPhp(
    PhpRelease release,
    String destDir, {
    void Function(DownloadProgress)? onProgress,
  }) => _artifacts.download(release, destDir, onProgress: onProgress);

  @override
  Future<bool> verifySha256(File file, String expectedHash) =>
      _artifacts.verifySha256(file, expectedHash);

  @override
  Future<void> dispose() async => _artifacts.dispose(); // closes _client

  @override
  Future<void> preInstall(String version) async {}

  @override
  Future<void> onInstalling(String version, double progress) async {}

  @override
  Future<void> postInstall(String version) async {}

  @override
  Future<void> onInstallFailed(String version, Exception error) async {}
}
