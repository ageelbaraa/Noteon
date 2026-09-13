import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../folders/data/folder.dart';
import '../../notes/data/media_ref.dart';
import '../../notes/data/note.dart';
import '../../tags/data/tag.dart';
import '../domain/backup_models.dart';

/// Unencrypted ZIP payload carried inside a `.noteonbak` file.
class BackupPayload {
  const BackupPayload({
    required this.manifest,
    required this.folders,
    required this.tags,
    required this.notes,
    required this.media,
  });

  final BackupManifest manifest;
  final List<Map<String, Object?>> folders;
  final List<Map<String, Object?>> tags;
  final List<Map<String, Object?>> notes;

  /// Relative path → file bytes.
  final Map<String, Uint8List> media;
}

/// Packs / unpacks the ZIP payload and serializes entity records.
abstract final class BackupPayloadIo {
  static const manifestFile = 'manifest.json';
  static const foldersFile = 'folders.json';
  static const tagsFile = 'tags.json';
  static const notesFile = 'notes.json';
  static const mediaPrefix = 'media/';

  static Uint8List encodeZip(BackupPayload payload) {
    final archive = Archive();
    void addJson(String name, Object value) {
      final bytes = utf8.encode(jsonEncode(value));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addJson(manifestFile, payload.manifest.toJson());
    addJson(foldersFile, payload.folders);
    addJson(tagsFile, payload.tags);
    addJson(notesFile, payload.notes);

    final paths = payload.media.keys.toList()..sort();
    for (final relative in paths) {
      final bytes = payload.media[relative]!;
      final name = '$mediaPrefix${relative.replaceAll('\\', '/')}';
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  static BackupPayload decodeZip(Uint8List zipBytes) {
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw const BackupException(BackupErrorCode.corruptPayload);
    }

    Map<String, Object?>? manifestMap;
    List<Map<String, Object?>> folders = const [];
    List<Map<String, Object?>> tags = const [];
    List<Map<String, Object?>> notes = const [];
    final media = <String, Uint8List>{};

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');
      final content = file.content;

      if (name == manifestFile) {
        final decoded = jsonDecode(utf8.decode(content));
        if (decoded is Map) {
          manifestMap = decoded.cast<String, Object?>();
        }
      } else if (name == foldersFile) {
        folders = _asObjectList(content);
      } else if (name == tagsFile) {
        tags = _asObjectList(content);
      } else if (name == notesFile) {
        notes = _asObjectList(content);
      } else if (name.startsWith(mediaPrefix)) {
        final relative = name.substring(mediaPrefix.length);
        if (relative.isNotEmpty) {
          media[relative] = content;
        }
      }
    }

    if (manifestMap == null) {
      throw const BackupException(BackupErrorCode.corruptPayload, 'missing manifest');
    }

    final manifest = BackupManifest.fromJson(manifestMap);
    if (manifest.noteCount != notes.length ||
        manifest.folderCount != folders.length ||
        manifest.tagCount != tags.length ||
        manifest.mediaCount != media.length) {
      throw const BackupException(
        BackupErrorCode.corruptPayload,
        'manifest count mismatch',
      );
    }

    return BackupPayload(
      manifest: manifest,
      folders: folders,
      tags: tags,
      notes: notes,
      media: media,
    );
  }

  static Map<String, Object?> folderToJson(Folder folder) => {
        'id': folder.id,
        'name': folder.name,
        'parentFolderId': folder.parentFolderId,
        'createdAt': folder.createdAt.toUtc().toIso8601String(),
        'updatedAt': folder.updatedAt.toUtc().toIso8601String(),
      };

  static Map<String, Object?> tagToJson(Tag tag) => {
        'id': tag.id,
        'name': tag.name,
        'createdAt': tag.createdAt.toUtc().toIso8601String(),
      };

  static Map<String, Object?> noteToJson(Note note) => {
        'id': note.id,
        'title': note.title,
        'contentJson': note.contentJson,
        'contentCiphertext': note.contentCiphertext,
        'encryptionSalt': note.encryptionSalt,
        'encryptionNonce': note.encryptionNonce,
        'passwordVerifier': note.passwordVerifier,
        'isLocked': note.isLocked,
        'folderId': note.folderId,
        'tagIds': List<int>.from(note.tagIds),
        'mediaRefs': note.mediaRefs
            .map(
              (ref) => {
                'relativePath': ref.relativePath,
                'kind': ref.kind,
                'createdAt': ref.createdAt?.toUtc().toIso8601String(),
              },
            )
            .toList(),
        'createdAt': note.createdAt.toUtc().toIso8601String(),
        'updatedAt': note.updatedAt.toUtc().toIso8601String(),
      };

  static Folder folderFromJson(Map<String, Object?> json) {
    return Folder()
      ..id = json['id'] as int
      ..name = (json['name'] as String?)?.trim() ?? ''
      ..parentFolderId = json['parentFolderId'] as int?
      ..createdAt = _parseDate(json['createdAt'])
      ..updatedAt = _parseDate(json['updatedAt']);
  }

  static Tag tagFromJson(Map<String, Object?> json) {
    return Tag()
      ..id = json['id'] as int
      ..name = (json['name'] as String?)?.trim() ?? ''
      ..createdAt = _parseDate(json['createdAt']);
  }

  static Note noteFromJson(Map<String, Object?> json) {
    final mediaRaw = json['mediaRefs'];
    final mediaRefs = <MediaRef>[];
    if (mediaRaw is List) {
      for (final item in mediaRaw) {
        if (item is! Map) continue;
        final map = item.cast<String, Object?>();
        mediaRefs.add(
          MediaRef()
            ..relativePath = (map['relativePath'] as String? ?? '')
                .replaceAll('\\', '/')
            ..kind = map['kind'] as String? ?? 'image'
            ..createdAt = map['createdAt'] == null
                ? null
                : _parseDate(map['createdAt']),
        );
      }
    }

    final tagIdsRaw = json['tagIds'];
    final tagIds = <int>[];
    if (tagIdsRaw is List) {
      for (final id in tagIdsRaw) {
        if (id is int) tagIds.add(id);
      }
    }

    return Note()
      ..id = json['id'] as int
      ..title = json['title'] as String? ?? ''
      ..contentJson = json['contentJson'] as String? ?? ''
      ..contentCiphertext = json['contentCiphertext'] as String?
      ..encryptionSalt = json['encryptionSalt'] as String?
      ..encryptionNonce = json['encryptionNonce'] as String?
      ..passwordVerifier = json['passwordVerifier'] as String?
      ..isLocked = json['isLocked'] as bool? ?? false
      ..folderId = json['folderId'] as int?
      ..tagIds = tagIds
      ..mediaRefs = mediaRefs
      ..createdAt = _parseDate(json['createdAt'])
      ..updatedAt = _parseDate(json['updatedAt']);
  }

  /// Rewrites Quill image embed paths using [pathMap].
  static String remapContentJsonPaths(
    String contentJson,
    Map<String, String> pathMap,
  ) {
    if (contentJson.trim().isEmpty || pathMap.isEmpty) {
      return contentJson;
    }
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! List) return contentJson;
      for (final op in decoded) {
        if (op is! Map) continue;
        final insert = op['insert'];
        if (insert is Map && insert['image'] is String) {
          final old = (insert['image'] as String).replaceAll('\\', '/');
          final mapped = pathMap[old];
          if (mapped != null) {
            insert['image'] = mapped;
          }
        }
      }
      return jsonEncode(decoded);
    } catch (_) {
      return contentJson;
    }
  }

  static List<Map<String, Object?>> _asObjectList(Uint8List content) {
    final decoded = jsonDecode(utf8.decode(content));
    if (decoded is! List) {
      throw const BackupException(BackupErrorCode.corruptPayload);
    }
    return decoded
        .whereType<Map>()
        .map((e) => e.cast<String, Object?>())
        .toList();
  }

  static DateTime _parseDate(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }
}
