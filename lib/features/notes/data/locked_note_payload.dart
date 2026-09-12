import 'dart:convert';
import 'dart:typed_data';

/// JSON payload sealed inside [Note.contentCiphertext] for locked notes.
class LockedNotePayload {
  const LockedNotePayload({
    required this.contentJson,
    required this.media,
    this.version = 1,
  });

  final int version;
  final String contentJson;
  final List<LockedMediaEntry> media;

  Map<String, dynamic> toJson() => {
        'v': version,
        'contentJson': contentJson,
        'media': media.map((m) => m.toJson()).toList(),
      };

  factory LockedNotePayload.fromJson(Map<String, dynamic> json) {
    final mediaJson = json['media'];
    return LockedNotePayload(
      version: json['v'] as int? ?? 1,
      contentJson: json['contentJson'] as String? ?? '',
      media: mediaJson is List
          ? mediaJson
              .whereType<Map>()
              .map(
                (item) => LockedMediaEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }

  String encode() => jsonEncode(toJson());

  static LockedNotePayload decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid locked payload');
    }
    return LockedNotePayload.fromJson(decoded);
  }
}

/// One encrypted media file belonging to a locked note.
class LockedMediaEntry {
  const LockedMediaEntry({
    required this.relativePath,
    required this.kind,
    required this.encryptedRelativePath,
    required this.nonceB64,
  });

  /// Logical path referenced by Quill Delta embeds.
  final String relativePath;

  final String kind;

  /// On-disk ciphertext under noteon_media.
  final String encryptedRelativePath;

  final String nonceB64;

  Map<String, dynamic> toJson() => {
        'relativePath': relativePath,
        'kind': kind,
        'encryptedRelativePath': encryptedRelativePath,
        'nonceB64': nonceB64,
      };

  factory LockedMediaEntry.fromJson(Map<String, dynamic> json) {
    return LockedMediaEntry(
      relativePath: json['relativePath'] as String? ?? '',
      kind: json['kind'] as String? ?? 'image',
      encryptedRelativePath: json['encryptedRelativePath'] as String? ?? '',
      nonceB64: json['nonceB64'] as String? ?? '',
    );
  }

  Uint8List get nonceBytes => base64Decode(nonceB64);
}
