import 'package:isar_community/isar.dart';

import 'media_ref.dart';

part 'note.g.dart';

/// Local note entity.
///
/// Content is stored as Quill Delta JSON in [contentJson] when unlocked.
/// When [isLocked] is true, body + media metadata live in [contentCiphertext]
/// (AES-GCM); [contentJson] and [mediaRefs] are cleared on disk.
@collection
class Note {
  Id id = Isar.autoIncrement;

  /// Display title shown in lists.
  @Index(caseSensitive: false)
  String title = '';

  /// Quill Delta JSON for the rich-text body (plaintext when unlocked).
  String contentJson = '';

  /// Base64(AES-GCM ciphertext || 16-byte MAC) for locked note payload.
  String? contentCiphertext;

  /// Base64 salt for PBKDF2-HMAC-SHA256 key derivation.
  String? encryptionSalt;

  /// Base64 AES-GCM nonce for [contentCiphertext].
  String? encryptionNonce;

  /// Base64 HMAC-SHA256 verifier derived from the note key (never the password).
  String? passwordVerifier;

  /// Whether this note's body is password-protected.
  @Index()
  bool isLocked = false;

  /// Optional owning folder. Null means the note is unfiled.
  @Index()
  int? folderId;

  /// Many-to-many style link to [Tag] records via stored IDs.
  @Index(type: IndexType.value)
  List<int> tagIds = [];

  /// Local media attachments (images/sketches) referenced by relative path.
  List<MediaRef> mediaRefs = [];

  @Index()
  DateTime createdAt = DateTime.now();

  /// Used for "group by date" and recent sorting.
  @Index()
  DateTime updatedAt = DateTime.now();
}
