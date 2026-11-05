import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

/// Metadata PVM writes into `versions/<v>/.pvm-install.json` at install time.
///
/// It records where a build came from, whether its archive checksum was
/// verified against a published value, and a SHA-256 of every installed file,
/// so `pvm doctor --verify` can detect files changed after installation.
class InstallRecord {
  static const fileName = '.pvm-install.json';
  static const schemaVersion = 1;

  final String version;
  final String sourceUrl;
  final String archiveSha256;
  final bool verified;
  final DateTime installedAt;

  /// Relative path (always `/`-separated) → lowercase hex SHA-256.
  final Map<String, String> files;

  const InstallRecord({
    required this.version,
    required this.sourceUrl,
    required this.archiveSha256,
    required this.verified,
    required this.installedAt,
    required this.files,
  });

  Map<String, Object> toJson() => {
    'schema': schemaVersion,
    'version': version,
    'sourceUrl': sourceUrl,
    'archiveSha256': archiveSha256,
    'verified': verified,
    'installedAt': installedAt.toIso8601String(),
    'files': files,
  };

  factory InstallRecord.fromJson(Map<String, dynamic> json) => InstallRecord(
    version: json['version'] as String,
    sourceUrl: json['sourceUrl'] as String? ?? '',
    archiveSha256: json['archiveSha256'] as String? ?? '',
    verified: json['verified'] as bool? ?? false,
    installedAt:
        DateTime.tryParse(json['installedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    files: (json['files'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, v as String),
    ),
  );

  Future<void> writeTo(String versionDir) => File(
    p.join(versionDir, fileName),
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(toJson()));

  /// Returns `null` when no record exists (e.g. versions installed before
  /// this feature, or copied in by hand).
  static Future<InstallRecord?> readFrom(String versionDir) async {
    final file = File(p.join(versionDir, fileName));
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString());
    return InstallRecord.fromJson(json as Map<String, dynamic>);
  }

  /// SHA-256 of every regular file under [dir] (except the record itself).
  static Future<Map<String, String>> hashTree(String dir) async {
    final root = p.normalize(p.absolute(dir));
    final result = <String, String>{};
    await for (final entity in Directory(
      root,
    ).list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = p.posix.joinAll(p.split(p.relative(entity.path, from: root)));
      if (rel == fileName) continue;
      result[rel] = crypto.sha256
          .convert(await entity.readAsBytes())
          .toString();
    }
    return result;
  }

  /// Compares the files on disk with the recorded hashes.
  Future<InstallVerification> verify(String versionDir) async {
    final actual = await hashTree(versionDir);
    final modified = <String>[];
    final missing = <String>[];
    files.forEach((rel, hash) {
      final now = actual[rel];
      if (now == null) {
        missing.add(rel);
      } else if (now != hash) {
        modified.add(rel);
      }
    });
    final added = actual.keys.where((k) => !files.containsKey(k)).toList()
      ..sort();
    modified.sort();
    missing.sort();
    return InstallVerification(
      modified: modified,
      missing: missing,
      added: added,
    );
  }
}

class InstallVerification {
  final List<String> modified;
  final List<String> missing;

  /// Files that were not part of the install (php.ini, extra extensions…).
  /// Reported for information only; adding config is normal.
  final List<String> added;

  const InstallVerification({
    required this.modified,
    required this.missing,
    required this.added,
  });

  bool get isIntact => modified.isEmpty && missing.isEmpty;
}
