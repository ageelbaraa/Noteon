import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

import 'note_content_codec.dart';

/// Helpers for image embeds stored inside Quill Delta JSON.
abstract final class NoteMediaPaths {
  /// Relative paths embedded as Quill `image` inserts.
  static List<String> extractFromContentJson(String contentJson) {
    if (contentJson.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! List) {
        return const [];
      }

      final paths = <String>[];
      for (final op in decoded) {
        if (op is! Map) {
          continue;
        }
        final insert = op['insert'];
        if (insert is Map && insert['image'] is String) {
          final path = (insert['image'] as String).trim();
          if (path.isNotEmpty) {
            paths.add(path.replaceAll('\\', '/'));
          }
        }
      }
      return paths;
    } catch (_) {
      // Fall back to document API when raw JSON parsing fails.
      try {
        final doc = NoteContentCodec.documentFromJson(contentJson);
        return extractFromDocument(doc);
      } catch (_) {
        return const [];
      }
    }
  }

  static List<String> extractFromDocument(Document document) {
    final paths = <String>[];
    for (final op in document.toDelta().toList()) {
      final data = op.data;
      if (data is Map && data[BlockEmbed.imageType] is String) {
        final path = (data[BlockEmbed.imageType] as String).trim();
        if (path.isNotEmpty) {
          paths.add(path.replaceAll('\\', '/'));
        }
      }
    }
    return paths;
  }
}
