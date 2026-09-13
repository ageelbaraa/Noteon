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
      final body = documentFromJson(contentJson).toPlainText().trim();
      final tables = _tablePlainText(contentJson).trim();
      final combined = [body, tables]
          .where((part) => part.isNotEmpty)
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (combined.isEmpty) {
        return '';
      }
      if (combined.length <= maxLength) {
        return combined;
      }
      return '${combined.substring(0, maxLength).trimRight()}…';
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
    final hasTables = contentJson.contains('"noteonTable"');
    return !hasTitle && !hasBody && !hasImages && !hasTables;
  }

  static String _tablePlainText(String contentJson) {
    if (!contentJson.contains('noteonTable')) {
      return '';
    }
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! List) {
        return '';
      }
      final parts = <String>[];
      for (final op in decoded) {
        if (op is! Map) {
          continue;
        }
        final insert = op['insert'];
        if (insert is! Map) {
          continue;
        }
        if (insert['noteonTable'] is String) {
          parts.add(_cellsPlain(insert['noteonTable'] as String));
        } else if (insert['custom'] is String) {
          final customRaw = insert['custom'] as String;
          if (!customRaw.contains('noteonTable')) {
            continue;
          }
          try {
            final nested = jsonDecode(customRaw);
            if (nested is Map && nested['noteonTable'] is String) {
              parts.add(_cellsPlain(nested['noteonTable'] as String));
            }
          } catch (_) {
            // Ignore malformed custom embeds.
          }
        }
      }
      return parts.where((p) => p.isNotEmpty).join(' ');
    } catch (_) {
      return '';
    }
  }

  static String _cellsPlain(String tableJson) {
    try {
      final decoded = jsonDecode(tableJson);
      if (decoded is! Map) {
        return '';
      }
      final cells = decoded['cells'];
      if (cells is! List) {
        return '';
      }
      final parts = <String>[];
      for (final row in cells) {
        if (row is! List) {
          continue;
        }
        for (final cell in row) {
          final text = '$cell'.trim();
          if (text.isNotEmpty) {
            parts.add(text);
          }
        }
      }
      return parts.join(' ');
    } catch (_) {
      return '';
    }
  }
}
