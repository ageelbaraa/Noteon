import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/note_crypto_service.dart';
import '../../../core/media/media_storage_service.dart';
import '../../folders/data/folder.dart';
import '../../notes/data/media_ref.dart';
import '../../notes/data/note.dart';
import '../../notes/data/note_media_paths.dart';
import '../../tags/data/tag.dart';
import '../domain/backup_models.dart';
import 'backup_payload_io.dart';
import 'noteon_backup_codec.dart';

/// Builds, seals, opens, and commits encrypted `.noteonbak` archives.
class BackupService {
  BackupService({
    required Isar isar,
    required MediaStorageService media,
    required NoteCryptoService crypto,
    Uuid? uuid,
  })  : _isar = isar,
        _media = media,
        _crypto = crypto,
        _uuid = uuid ?? const Uuid();

  final Isar _isar;
  final MediaStorageService _media;
  final NoteCryptoService _crypto;
  final Uuid _uuid;

  static const minPassphraseLength = 4;

  /// Packs the full library into an encrypted `.noteonbak` byte array.
  Future<Uint8List> exportEncryptedBackup({
    required String passphrase,
  }) async {
    if (passphrase.length < minPassphraseLength) {
      throw const BackupException(BackupErrorCode.passphraseTooShort);
    }

    final folders = await _isar.folders.where().findAll();
    final tags = await _isar.tags.where().findAll();
    final notes = await _isar.notes.where().findAll();

    final mediaPaths = await _collectMediaPaths(notes);
    final mediaBytes = <String, Uint8List>{};
    for (final relative in mediaPaths) {
      final bytes = await _media.readBytesAtRelativePath(relative);
      if (bytes == null) {
        throw BackupException(
          BackupErrorCode.missingMedia,
          relative,
        );
      }
      mediaBytes[relative] = bytes;
    }

    final createdAt = DateTime.now().toUtc();
    final manifest = BackupManifest(
      version: NoteonBackupCodec.currentVersion,
      createdAt: createdAt,
      noteCount: notes.length,
      folderCount: folders.length,
      tagCount: tags.length,
      mediaCount: mediaBytes.length,
    );

    final zipBytes = BackupPayloadIo.encodeZip(
      BackupPayload(
        manifest: manifest,
        folders: folders.map(BackupPayloadIo.folderToJson).toList(),
        tags: tags.map(BackupPayloadIo.tagToJson).toList(),
        notes: notes.map(BackupPayloadIo.noteToJson).toList(),
        media: mediaBytes,
      ),
    );

    final digest = await Sha256().hash(zipBytes);
    final payloadSha256B64 = base64Encode(digest.bytes);

    final salt = _crypto.generateSalt();
    final key = await _crypto.deriveKey(password: passphrase, salt: salt);
    final sealed = await _crypto.encryptBytes(clearBytes: zipBytes, key: key);

    final header = <String, Object?>{
      ...manifest.toJson(),
      'payloadSha256B64': payloadSha256B64,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _crypto.pbkdf2Iterations,
      'saltB64': base64Encode(salt),
      'nonceB64': base64Encode(sealed.nonce),
    };

    return NoteonBackupCodec.encode(
      header: header,
      ciphertextWithMac: sealed.ciphertextWithMac,
    );
  }

  /// Decrypts and validates a `.noteonbak` file without mutating local data.
  Future<BackupPayload> openEncryptedBackup({
    required Uint8List fileBytes,
    required String passphrase,
  }) async {
    if (passphrase.length < minPassphraseLength) {
      throw const BackupException(BackupErrorCode.passphraseTooShort);
    }

    final file = NoteonBackupCodec.decode(fileBytes);
    final saltB64 = file.header['saltB64'] as String?;
    final nonceB64 = file.header['nonceB64'] as String?;
    final iterations = file.header['iterations'] as int?;
    final expectedHash = file.header['payloadSha256B64'] as String? ?? '';

    if (saltB64 == null ||
        nonceB64 == null ||
        iterations == null ||
        expectedHash.isEmpty) {
      throw const BackupException(BackupErrorCode.invalidFormat);
    }

    late final Uint8List zipBytes;
    try {
      final key = await _crypto.deriveKey(
        password: passphrase,
        salt: base64Decode(saltB64),
        iterations: iterations,
      );
      zipBytes = await _crypto.decryptBytes(
        ciphertextWithMac: file.ciphertextWithMac,
        nonce: base64Decode(nonceB64),
        key: key,
      );
    } on NoteCryptoException catch (e) {
      if (e.code == NoteCryptoErrorCode.authenticationFailed) {
        throw const BackupException(BackupErrorCode.incorrectPassphrase);
      }
      throw const BackupException(BackupErrorCode.corruptPayload);
    }

    final digest = await Sha256().hash(zipBytes);
    late final List<int> expectedBytes;
    try {
      expectedBytes = base64Decode(expectedHash);
    } catch (_) {
      throw const BackupException(BackupErrorCode.corruptPayload);
    }
    if (!_crypto.constantTimeEquals(expectedBytes, digest.bytes)) {
      throw const BackupException(BackupErrorCode.corruptPayload, 'hash mismatch');
    }

    return BackupPayloadIo.decodeZip(zipBytes);
  }

  /// Commits a previously opened payload using [mode].
  Future<BackupImportResult> commitImport({
    required BackupPayload payload,
    required BackupImportMode mode,
  }) async {
    switch (mode) {
      case BackupImportMode.replace:
        return _commitReplace(payload);
      case BackupImportMode.merge:
        return _commitMerge(payload);
    }
  }

  Future<BackupImportResult> importEncryptedBackup({
    required Uint8List fileBytes,
    required String passphrase,
    required BackupImportMode mode,
  }) async {
    final payload = await openEncryptedBackup(
      fileBytes: fileBytes,
      passphrase: passphrase,
    );
    return commitImport(payload: payload, mode: mode);
  }

  Future<Set<String>> _collectMediaPaths(List<Note> notes) async {
    final paths = <String>{};
    for (final note in notes) {
      if (note.isLocked) {
        paths.addAll(await _media.listLockedMediaRelativePaths(note.id));
      } else {
        for (final ref in note.mediaRefs) {
          final path = ref.relativePath.replaceAll('\\', '/');
          if (path.isNotEmpty) paths.add(path);
        }
        paths.addAll(NoteMediaPaths.extractFromContentJson(note.contentJson));
      }
    }
    return paths;
  }

  Future<BackupImportResult> _commitReplace(BackupPayload payload) async {
    // Decrypt/verify already done — wipe only after payload is in memory.
    await _isar.writeTxn(() async {
      await _isar.notes.clear();
      await _isar.folders.clear();
      await _isar.tags.clear();
    });
    await _media.clearAllMedia();

    for (final entry in payload.media.entries) {
      await _media.writeBytesAtRelativePath(entry.key, entry.value);
    }

    final folders = payload.folders.map(BackupPayloadIo.folderFromJson).toList()
      ..sort(_folderDepthCompare);
    final tags = payload.tags.map(BackupPayloadIo.tagFromJson).toList();
    final notes = payload.notes.map(BackupPayloadIo.noteFromJson).toList();

    await _isar.writeTxn(() async {
      for (final folder in folders) {
        await _isar.folders.put(folder);
      }
      for (final tag in tags) {
        await _isar.tags.put(tag);
      }
      for (final note in notes) {
        await _isar.notes.put(note);
      }
    });

    return BackupImportResult(
      mode: BackupImportMode.replace,
      notesImported: notes.length,
      foldersImported: folders.length,
      tagsImported: tags.length,
      mediaImported: payload.media.length,
    );
  }

  Future<BackupImportResult> _commitMerge(BackupPayload payload) async {
    final folderIdMap = <int, int>{};
    final tagIdMap = <int, int>{};

    final folders = payload.folders.map(BackupPayloadIo.folderFromJson).toList()
      ..sort(_folderDepthCompare);

    for (final folder in folders) {
      final oldId = folder.id;
      final parentOld = folder.parentFolderId;
      final parentNew =
          parentOld == null ? null : folderIdMap[parentOld];
      final created = Folder()
        ..name = folder.name
        ..parentFolderId = parentNew
        ..createdAt = folder.createdAt
        ..updatedAt = folder.updatedAt;
      final newId = await _isar.writeTxn(() => _isar.folders.put(created));
      folderIdMap[oldId] = newId;
    }

    for (final raw in payload.tags) {
      final tag = BackupPayloadIo.tagFromJson(raw);
      final oldId = tag.id;
      final name = tag.name.trim();
      if (name.isEmpty) continue;

      final existing = await _isar.tags
          .filter()
          .nameEqualTo(name, caseSensitive: false)
          .findFirst();
      if (existing != null) {
        tagIdMap[oldId] = existing.id;
        continue;
      }
      final created = Tag()
        ..name = name
        ..createdAt = tag.createdAt;
      final newId = await _isar.writeTxn(() => _isar.tags.put(created));
      tagIdMap[oldId] = newId;
    }

    var notesImported = 0;
    for (final raw in payload.notes) {
      final source = BackupPayloadIo.noteFromJson(raw);
      final oldId = source.id;

      final remappedFolder = source.folderId == null
          ? null
          : folderIdMap[source.folderId!];
      final remappedTags = source.tagIds
          .map((id) => tagIdMap[id])
          .whereType<int>()
          .toList();

      String contentJson = source.contentJson;
      var mediaRefs = List<MediaRef>.from(source.mediaRefs);

      if (source.isLocked) {
        // Keep original locked/* paths so sealed ciphertext stays valid.
        for (final entry in payload.media.entries) {
          if (entry.key.startsWith('locked/$oldId/')) {
            await _media.writeBytesAtRelativePath(entry.key, entry.value);
          }
        }
      } else {
        final pathMap = <String, String>{};
        final needed = <String>{
          ...mediaRefs.map((r) => r.relativePath.replaceAll('\\', '/')),
          ...NoteMediaPaths.extractFromContentJson(contentJson),
        };
        for (final oldPath in needed) {
          final bytes = payload.media[oldPath];
          if (bytes == null) continue;
          final newPath = _newMediaPath(oldPath);
          await _media.writeBytesAtRelativePath(newPath, bytes);
          pathMap[oldPath] = newPath;
        }
        contentJson =
            BackupPayloadIo.remapContentJsonPaths(contentJson, pathMap);
        mediaRefs = mediaRefs.map((ref) {
          final old = ref.relativePath.replaceAll('\\', '/');
          final mapped = pathMap[old] ?? old;
          return MediaRef()
            ..relativePath = mapped
            ..kind = ref.kind
            ..createdAt = ref.createdAt;
        }).toList();
      }

      final note = Note()
        ..title = source.title
        ..contentJson = contentJson
        ..contentCiphertext = source.contentCiphertext
        ..encryptionSalt = source.encryptionSalt
        ..encryptionNonce = source.encryptionNonce
        ..passwordVerifier = source.passwordVerifier
        ..isLocked = source.isLocked
        ..folderId = remappedFolder
        ..tagIds = remappedTags
        ..mediaRefs = mediaRefs
        ..createdAt = source.createdAt
        ..updatedAt = source.updatedAt;

      await _isar.writeTxn(() => _isar.notes.put(note));
      notesImported++;
    }

    return BackupImportResult(
      mode: BackupImportMode.merge,
      notesImported: notesImported,
      foldersImported: folderIdMap.length,
      tagsImported: tagIdMap.length,
      mediaImported: payload.media.length,
    );
  }

  String _newMediaPath(String oldPath) {
    final normalized = oldPath.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final dir = slash >= 0 ? normalized.substring(0, slash) : 'images';
    final name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot) : '';
    return '$dir/${_uuid.v4()}$ext';
  }

  /// Parents before children so replace/merge can resolve parent IDs.
  static int _folderDepthCompare(Folder a, Folder b) {
    final aRoot = a.parentFolderId == null ? 0 : 1;
    final bRoot = b.parentFolderId == null ? 0 : 1;
    if (aRoot != bRoot) return aRoot.compareTo(bRoot);
    return a.id.compareTo(b.id);
  }
}
