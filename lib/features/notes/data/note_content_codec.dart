import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Helpers for Quill Delta JSON stored in [Note.contentJson].
abstract final class NoteContentCodec {
  /// Empty Quill document encoded as Delta JSON.
  static String emptyDeltaJson() {
    return jsonEncode(Document().toDelta().toJson());
  }

  /// Builds a [Document] from stored Delta JSON. Falls back to empty on errors.
  static Document documentFromJson(String contentJson) {
    if (contentJson.trim().isEmpty) {
      return Document();
    }
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is List) {
        return Document.fromJson(decoded);
      }
    } catch (_) {
      // Legacy / corrupt payloads become a plain-text document.
      return Document()..insert(0, contentJson);
    }
    return Document();
  }

  /// Serializes the controller document to Delta JSON for persistence.
  static String encodeDocument(Document document) {
    return jsonEncode(document.toDelta().toJson());
  }

  /// Plain-text preview for list rows. Empty when there is no visible text.
  static String plainTextPreview(String contentJson, {int maxLength = 120}) {
    try {
      final text = documentFromJson(contentJson).toPlainText().trim();
      if (text.isEmpty) {
        return '';
      }
      if (text.length <= maxLength) {
        return text;
      }
      return '${text.substring(0, maxLength).trimRight()}…';
    } catch (_) {
      return '';
    }
  }

  /// True when title, body text, and embeds have no meaningful user content.
  static bool isBlankNote({
    required String title,
    required String contentJson,
  }) {
    final hasTitle = title.trim().isNotEmpty;
    final hasBody = plainTextPreview(contentJson).isNotEmpty;
    final hasImages = contentJson.contains('"image"');
    return !hasTitle && !hasBody && !hasImages;
  }
}
