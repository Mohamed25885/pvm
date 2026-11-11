import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

/// How a slot's PHP was obtained. Serialised as [json].
enum SlotKind {
  static('static'),
  source('source'),
  windowsZip('windows-zip'),
  linked('linked');

  final String json;
  const SlotKind(this.json);

  static SlotKind parse(String? s) =>
      values.firstWhere((k) => k.json == s, orElse: () => windowsZip);
}

/// An extension installed into a slot by `pvm ext install`.
class ExtensionEntry {
  final String name;
  final String version;
  final String file;
  final String sha256;
  final bool verified;

  const ExtensionEntry({
    required this.name,
    required this.version,
    required this.file,
    required this.sha256,
    required this.verified,
  });

  Map<String, Object> toJson() => {
    'name': name,
    'version': version,
    'file': file,
    'sha256': sha256,
    'verified': verified,
  };

  factory ExtensionEntry.fromJson(Map<String, dynamic> json) => ExtensionEntry(
    name: json['name'] as String,
    version: json['version'] as String? ?? '',
    file: json['file'] as String? ?? '',
    sha256: json['sha256'] as String? ?? '',
    verified: json['verified'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is ExtensionEntry &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Metadata PVM writes into `versions/<v>/.pvm-install.json` at install time.
///
/// It records where a build came from, whether its archive checksum was
/// verified against a published value, and a SHA-256 of every installed file,
/// so `pvm doctor --verify` can detect files changed after installation.
/// Schema 2 adds the slot kind, probe results and installed extensions;
/// schema 1 records read back with Windows-zip defaults.
class InstallRecord {
  static const fileName = '.pvm-install.json';
  static const schemaVersion = 2;

  final String version;
  final String sourceUrl;
  final String archiveSha256;
  final bool verified;
  final DateTime installedAt;

  /// Relative path (always `/`-separated) → lowercase hex SHA-256.
  final Map<String, String> files;

  final SlotKind kind;
  final bool zts;
  final String arch;
  final String apiNo;
  final String? phpConfig;
  final String? prefix;
  final String extensionDir;
  final bool writable;
  final String? vsVersion;
  final List<ExtensionEntry> extensions;

  const InstallRecord({
    required this.version,
    required this.sourceUrl,
    required this.archiveSha256,
    required this.verified,
    required this.installedAt,
    required this.files,
    this.kind = SlotKind.windowsZip,
    this.zts = false,
    this.arch = 'x64',
    this.apiNo = '',
    this.phpConfig,
    this.prefix,
    this.extensionDir = '',
    this.writable = true,
    this.vsVersion,
    this.extensions = const [],
  });

  InstallRecord copyWith({
    String? version,
    String? sourceUrl,
    String? archiveSha256,
    bool? verified,
    DateTime? installedAt,
    Map<String, String>? files,
    SlotKind? kind,
    bool? zts,
    String? arch,
    String? apiNo,
    String? phpConfig,
    String? prefix,
    String? extensionDir,
    bool? writable,
    String? vsVersion,
    List<ExtensionEntry>? extensions,
  }) => InstallRecord(
    version: version ?? this.version,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    archiveSha256: archiveSha256 ?? this.archiveSha256,
    verified: verified ?? this.verified,
    installedAt: installedAt ?? this.installedAt,
    files: files ?? this.files,
    kind: kind ?? this.kind,
    zts: zts ?? this.zts,
    arch: arch ?? this.arch,
    apiNo: apiNo ?? this.apiNo,
    phpConfig: phpConfig ?? this.phpConfig,
    prefix: prefix ?? this.prefix,
    extensionDir: extensionDir ?? this.extensionDir,
    writable: writable ?? this.writable,
    vsVersion: vsVersion ?? this.vsVersion,
    extensions: extensions ?? this.extensions,
  );

  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    'version': version,
    'sourceUrl': sourceUrl,
    'archiveSha256': archiveSha256,
    'verified': verified,
    'installedAt': installedAt.toIso8601String(),
    'files': files,
    'kind': kind.json,
    'zts': zts,
    'arch': arch,
    'apiNo': apiNo,
    'phpConfig': phpConfig,
    'prefix': prefix,
    'extensionDir': extensionDir,
    'writable': writable,
    'vsVersion': vsVersion,
    'extensions': extensions.map((e) => e.toJson()).toList(),
  };

  /// [defaultExtensionDir] fills `extensionDir` for records that lack it (v1).
  factory InstallRecord.fromJson(
    Map<String, dynamic> json, {
    String defaultExtensionDir = '',
  }) => InstallRecord(
    version: json['version'] as String,
    sourceUrl: json['sourceUrl'] as String? ?? '',
    archiveSha256: json['archiveSha256'] as String? ?? '',
    verified: json['verified'] as bool? ?? false,
    installedAt:
        DateTime.tryParse(json['installedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    files: (json['files'] as Map? ?? const {}).map(
      (k, v) => MapEntry(k as String, v as String),
    ),
    kind: SlotKind.parse(json['kind'] as String?),
    zts: json['zts'] as bool? ?? false,
    arch: json['arch'] as String? ?? 'x64',
    apiNo: json['apiNo'] as String? ?? '',
    phpConfig: json['phpConfig'] as String?,
    prefix: json['prefix'] as String?,
    extensionDir: switch (json['extensionDir']) {
      final String d when d.isNotEmpty => d,
      _ => defaultExtensionDir,
    },
    writable: json['writable'] as bool? ?? true,
    vsVersion: json['vsVersion'] as String?,
    extensions: (json['extensions'] as List<dynamic>? ?? const [])
        .map((e) => ExtensionEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  @override
  bool operator ==(Object other) =>
      other is InstallRecord &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;

  Future<void> writeTo(String versionDir) =>
      writeToFile(p.join(versionDir, fileName));

  /// Writes the record to [path], creating its parent directory.
  Future<void> writeToFile(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }

  /// Returns `null` when no record exists (e.g. versions installed before
  /// this feature, or copied in by hand).
  static Future<InstallRecord?> readFrom(String versionDir) => readFromFile(
    p.join(versionDir, fileName),
    defaultExtensionDir: p.join(versionDir, 'ext'),
  );

  /// Like [readFrom] for a record at an explicit [path].
  static Future<InstallRecord?> readFromFile(
    String path, {
    String defaultExtensionDir = '',
  }) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString());
    return InstallRecord.fromJson(
      json as Map<String, dynamic>,
      defaultExtensionDir: defaultExtensionDir,
    );
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
