import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/crypto/note_crypto_service.dart';
import '../../../core/media/media_storage_service.dart';
import 'locked_note_payload.dart';
import 'media_ref.dart';
import 'note.dart';
import 'note_content_codec.dart';
import 'note_media_paths.dart';

/// In-memory unlocked state for a password-protected note.
///
/// Cleared when the editor closes or the password is removed. Never persisted.
class UnlockedNoteSession {
  UnlockedNoteSession({
    required this.noteId,
    required this.key,
    required this.contentJson,
    required this.mediaRefs,
    required this.mediaBytes,
    required this.salt,
    required this.passwordVerifier,
  });

  final int noteId;
  final SecretKey key;
  String contentJson;
  List<MediaRef> mediaRefs;

  /// Decrypted media keyed by the logical relative path used in Quill embeds.
  final Map<String, Uint8List> mediaBytes;

  final Uint8List salt;
  final Uint8List passwordVerifier;

  void clearSensitive() {
    contentJson = NoteContentCodec.emptyDeltaJson();
    mediaRefs = [];
    mediaBytes.clear();
  }
}

/// Locks, unlocks, and re-encrypts notes with AES-GCM + PBKDF2.
class NoteLockService {
  NoteLockService({
    required NoteCryptoService crypto,
    required MediaStorageService media,
  })  : _crypto = crypto,
        _media = media;

  final NoteCryptoService _crypto;
  final MediaStorageService _media;

  static const minPasswordLength = 4;

  /// Encrypts note body + media, clears plaintext fields, sets [Note.isLocked].
  Future<void> lockNote({
    required Note note,
    required String password,
    required String contentJson,
    required List<MediaRef> mediaRefs,
  }) async {
    _validatePassword(password);
    if (note.isLocked) {
      throw const NoteCryptoException(NoteCryptoErrorCode.alreadyLocked);
    }

    final salt = _crypto.generateSalt();
    final key = await _crypto.deriveKey(password: password, salt: salt);
    final verifier = await _crypto.createPasswordVerifier(key);

    await _sealAndPersist(
      note: note,
      key: key,
      salt: salt,
      verifier: verifier,
      contentJson: contentJson,
      mediaRefs: mediaRefs,
    );
  }

  /// Authenticates and returns an in-memory session (disk stays encrypted).
  Future<UnlockedNoteSession> unlockNote({
    required Note note,
    required String password,
  }) async {
    if (!note.isLocked) {
      throw const NoteCryptoException(NoteCryptoErrorCode.notLocked);
    }

    final saltB64 = note.encryptionSalt;
    final nonceB64 = note.encryptionNonce;
    final cipherB64 = note.contentCiphertext;
    final verifierB64 = note.passwordVerifier;
    if (saltB64 == null ||
        nonceB64 == null ||
        cipherB64 == null ||
        verifierB64 == null) {
      throw const NoteCryptoException(NoteCryptoErrorCode.missingData);
    }

    late final Uint8List salt;
    late final Uint8List nonce;
    late final Uint8List ciphertext;
    late final Uint8List storedVerifier;
    try {
      salt = base64Decode(saltB64);
      nonce = base64Decode(nonceB64);
      ciphertext = base64Decode(cipherB64);
      storedVerifier = base64Decode(verifierB64);
    } on FormatException {
      throw const NoteCryptoException(NoteCryptoErrorCode.corruptData);
    }

    final key = await _crypto.deriveKey(password: password, salt: salt);
    final actualVerifier = await _crypto.createPasswordVerifier(key);
    if (!_crypto.constantTimeEquals(actualVerifier, storedVerifier)) {
      throw const NoteCryptoException(NoteCryptoErrorCode.incorrectPassword);
    }

    final clearUtf8 = await _crypto.decryptUtf8(
      ciphertextWithMac: ciphertext,
      nonce: nonce,
      key: key,
    );

    final LockedNotePayload payload;
    try {
      payload = LockedNotePayload.decode(clearUtf8);
    } on FormatException {
      throw const NoteCryptoException(NoteCryptoErrorCode.corruptData);
    }

    final mediaBytes = <String, Uint8List>{};
    final mediaRefs = <MediaRef>[];
    for (final entry in payload.media) {
      final encFile = await _media.fileFor(entry.encryptedRelativePath);
      if (encFile == null) {
        continue;
      }
      final encBytes = await encFile.readAsBytes();
      final clear = await _crypto.decryptBytes(
        ciphertextWithMac: encBytes,
        nonce: entry.nonceBytes,
        key: key,
      );
      mediaBytes[entry.relativePath] = clear;
      mediaRefs.add(
        MediaRef()
          ..relativePath = entry.relativePath
          ..kind = entry.kind
          ..createdAt = DateTime.now(),
      );
    }

    return UnlockedNoteSession(
      noteId: note.id,
      key: key,
      contentJson: payload.contentJson,
      mediaRefs: mediaRefs,
      mediaBytes: mediaBytes,
      salt: salt,
      passwordVerifier: storedVerifier,
    );
  }

  /// Re-encrypts current editor content using the unlocked session key.
  Future<void> saveUnlockedNote({
    required Note note,
    required UnlockedNoteSession session,
    required String contentJson,
    required List<MediaRef> mediaRefs,
  }) async {
    if (!note.isLocked || note.id != session.noteId) {
      throw const NoteCryptoException(NoteCryptoErrorCode.invalidSession);
    }

    await _sealAndPersist(
      note: note,
      key: session.key,
      salt: session.salt,
      verifier: session.passwordVerifier,
      contentJson: contentJson,
      mediaRefs: mediaRefs,
      existingMediaBytes: session.mediaBytes,
    );

    // Refresh session media map from newly sealed logical paths.
    session.contentJson = contentJson;
    session.mediaRefs = List<MediaRef>.from(mediaRefs);
  }

  /// Decrypts permanently: clears crypto fields and writes plaintext + media.
  Future<void> removePassword({
    required Note note,
    required UnlockedNoteSession session,
    required String contentJson,
    required List<MediaRef> mediaRefs,
  }) async {
    if (!note.isLocked || note.id != session.noteId) {
      throw const NoteCryptoException(NoteCryptoErrorCode.invalidSession);
    }

    final livePaths = NoteMediaPaths.extractFromContentJson(contentJson).toSet();
    final writtenRefs = <MediaRef>[];

    for (final path in livePaths) {
      final bytes = session.mediaBytes[path] ??
          await _readPlainOrNull(path);
      if (bytes == null) {
        continue;
      }
      final kind = path.startsWith('${MediaStorageService.sketchesSubdirectory}/')
          ? 'sketch'
          : 'image';
      // Persist plaintext under the same logical path when possible.
      await _media.writeBytesAtRelativePath(path, bytes);
      writtenRefs.add(
        MediaRef()
          ..relativePath = path
          ..kind = kind
          ..createdAt = DateTime.now(),
      );
    }

    await _media.deleteNoteLockedMedia(note.id);

    note
      ..contentJson = contentJson
      ..mediaRefs = writtenRefs
      ..isLocked = false
      ..contentCiphertext = null
      ..encryptionSalt = null
      ..encryptionNonce = null
      ..passwordVerifier = null;

    session.clearSensitive();
  }

  Future<void> _sealAndPersist({
    required Note note,
    required SecretKey key,
    required Uint8List salt,
    required Uint8List verifier,
    required String contentJson,
    required List<MediaRef> mediaRefs,
    Map<String, Uint8List>? existingMediaBytes,
  }) async {
    final livePaths = {
      ...NoteMediaPaths.extractFromContentJson(contentJson),
      ...mediaRefs.map((r) => r.relativePath),
    }.map((p) => p.replaceAll('\\', '/')).where((p) => p.isNotEmpty).toSet();

    final previousEncrypted =
        await _media.listLockedMediaRelativePaths(note.id);

    final lockedEntries = <LockedMediaEntry>[];
    final refreshedBytes = <String, Uint8List>{};

    for (final logicalPath in livePaths) {
      var kind = logicalPath.startsWith(
              '${MediaStorageService.sketchesSubdirectory}/',
            )
          ? 'sketch'
          : 'image';
      for (final ref in mediaRefs) {
        if (ref.relativePath == logicalPath) {
          kind = ref.kind;
          break;
        }
      }

      final clearBytes = existingMediaBytes?[logicalPath] ??
          await _readPlainOrNull(logicalPath);
      if (clearBytes == null) {
        continue;
      }

      final package = await _crypto.encryptBytes(
        clearBytes: clearBytes,
        key: key,
      );
      final encRelative = await _media.writeLockedCiphertext(
        noteId: note.id,
        ciphertextWithMac: package.ciphertextWithMac,
      );
      lockedEntries.add(
        LockedMediaEntry(
          relativePath: logicalPath,
          kind: kind,
          encryptedRelativePath: encRelative,
          nonceB64: base64Encode(package.nonce),
        ),
      );
      refreshedBytes[logicalPath] = clearBytes;

      // Remove plaintext original if it lived on disk.
      if (!logicalPath.startsWith('${MediaStorageService.lockedSubdirectory}/')) {
        await _media.deleteRelativePath(logicalPath);
      }
    }

    for (final oldPath in previousEncrypted) {
      final stillUsed =
          lockedEntries.any((e) => e.encryptedRelativePath == oldPath);
      if (!stillUsed) {
        await _media.deleteRelativePath(oldPath);
      }
    }

    final payload = LockedNotePayload(
      contentJson: contentJson,
      media: lockedEntries,
    );
    final sealed = await _crypto.encryptUtf8(
      clearText: payload.encode(),
      key: key,
    );

    note
      ..contentJson = ''
      ..mediaRefs = []
      ..isLocked = true
      ..contentCiphertext = base64Encode(sealed.ciphertextWithMac)
      ..encryptionSalt = base64Encode(salt)
      ..encryptionNonce = base64Encode(sealed.nonce)
      ..passwordVerifier = base64Encode(verifier);

    existingMediaBytes
      ?..clear()
      ..addAll(refreshedBytes);
  }

  Future<Uint8List?> _readPlainOrNull(String relativePath) async {
    final file = await _media.fileFor(relativePath);
    if (file == null) {
      return null;
    }
    return file.readAsBytes();
  }

  void _validatePassword(String password) {
    if (password.length < minPasswordLength) {
      throw const NoteCryptoException(NoteCryptoErrorCode.passwordTooShort);
    }
  }
}
