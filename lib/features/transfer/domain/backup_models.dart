/// How an imported backup is applied to the local library.
enum BackupImportMode {
  /// Keep existing notes; assign new IDs to imported entities.
  merge,

  /// Wipe the local library, then restore backup IDs and paths.
  replace,
}

/// Plaintext counts embedded in the backup header / manifest.
class BackupManifest {
  const BackupManifest({
    required this.version,
    required this.createdAt,
    required this.noteCount,
    required this.folderCount,
    required this.tagCount,
    required this.mediaCount,
  });

  final int version;
  final DateTime createdAt;
  final int noteCount;
  final int folderCount;
  final int tagCount;
  final int mediaCount;

  Map<String, Object?> toJson() => {
        'format': 'noteonbak',
        'version': version,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'noteCount': noteCount,
        'folderCount': folderCount,
        'tagCount': tagCount,
        'mediaCount': mediaCount,
      };

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    return BackupManifest(
      version: json['version'] as int? ?? 1,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      noteCount: json['noteCount'] as int? ?? 0,
      folderCount: json['folderCount'] as int? ?? 0,
      tagCount: json['tagCount'] as int? ?? 0,
      mediaCount: json['mediaCount'] as int? ?? 0,
    );
  }
}

/// Result returned after a successful import commit.
class BackupImportResult {
  const BackupImportResult({
    required this.mode,
    required this.notesImported,
    required this.foldersImported,
    required this.tagsImported,
    required this.mediaImported,
  });

  final BackupImportMode mode;
  final int notesImported;
  final int foldersImported;
  final int tagsImported;
  final int mediaImported;
}

/// Errors raised while packing, sealing, opening, or committing a backup.
class BackupException implements Exception {
  const BackupException(this.code, [this.debugMessage = '']);

  final BackupErrorCode code;
  final String debugMessage;

  @override
  String toString() => 'BackupException(${code.name})';
}

enum BackupErrorCode {
  passphraseTooShort,
  invalidFormat,
  unsupportedVersion,
  incorrectPassphrase,
  corruptPayload,
  missingMedia,
  cancelled,
  ioFailure,
}
