import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

import 'note_content_codec.dart';
import 'noteon_audio_payload.dart';
import 'noteon_image_payload.dart';
import 'noteon_ink_payload.dart';
import 'noteon_pdf_payload.dart';

/// Helpers for media embeds stored inside Quill Delta JSON.
abstract final class NoteMediaPaths {
  /// Relative paths from image, audio, ink, and PDF embeds (tables ignored).
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
        if (insert is! Map) {
          continue;
        }
        _collectFromInsert(insert, paths);
      }
      return paths;
    } catch (_) {
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
      if (data is! Map) {
        continue;
      }
      _collectFromInsert(data, paths);
    }
    return paths;
  }

  static void _collectFromInsert(Map<dynamic, dynamic> insert, List<String> paths) {
    if (insert.containsKey('image') || insert.containsKey(BlockEmbed.imageType)) {
      final raw = insert['image'] ?? insert[BlockEmbed.imageType];
      final path = NoteonImagePayload.decode(raw).path;
      if (path.isNotEmpty) {
        paths.add(path);
      }
    }
    final audioPath = _audioPathFromInsert(insert);
    if (audioPath != null && audioPath.isNotEmpty) {
      paths.add(audioPath);
    }
    paths.addAll(_inkPathsFromInsert(insert));
    paths.addAll(_pdfPathsFromInsert(insert));
  }

  static String? _audioPathFromInsert(Map<dynamic, dynamic> insert) {
    if (insert['noteonAudio'] is String) {
      return NoteonAudioPayload.decode(insert['noteonAudio']).path;
    }
    final custom = insert[BlockEmbed.customType] ?? insert['custom'];
    if (custom is! String || !custom.contains('noteonAudio')) {
      return null;
    }
    try {
      final nested = jsonDecode(custom);
      if (nested is Map && nested['noteonAudio'] is String) {
        return NoteonAudioPayload.decode(nested['noteonAudio']).path;
      }
    } catch (_) {
      // Ignore malformed custom embeds.
    }
    return null;
  }

  static List<String> _inkPathsFromInsert(Map<dynamic, dynamic> insert) {
    if (insert['noteonInk'] is String) {
      return NoteonInkPayload.decode(insert['noteonInk']).mediaPaths;
    }
    final custom = insert[BlockEmbed.customType] ?? insert['custom'];
    if (custom is! String || !custom.contains('noteonInk')) {
      return const [];
    }
    try {
      final nested = jsonDecode(custom);
      if (nested is Map && nested['noteonInk'] is String) {
        return NoteonInkPayload.decode(nested['noteonInk']).mediaPaths;
      }
    } catch (_) {
      // Ignore malformed custom embeds.
    }
    return const [];
  }

  static List<String> _pdfPathsFromInsert(Map<dynamic, dynamic> insert) {
    if (insert['noteonPdf'] is String) {
      return NoteonPdfPayload.decode(insert['noteonPdf']).mediaPaths;
    }
    final custom = insert[BlockEmbed.customType] ?? insert['custom'];
    if (custom is! String || !custom.contains('noteonPdf')) {
      return const [];
    }
    try {
      final nested = jsonDecode(custom);
      if (nested is Map && nested['noteonPdf'] is String) {
        return NoteonPdfPayload.decode(nested['noteonPdf']).mediaPaths;
      }
    } catch (_) {
      // Ignore malformed custom embeds.
    }
    return const [];
  }
}
