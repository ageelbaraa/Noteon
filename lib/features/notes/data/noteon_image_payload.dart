import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Parses and builds Quill `image` embed payloads.
///
/// Legacy notes store a plain relative path string.
/// Resized images store JSON: `{"path":"...","w":220}` — path extraction stays
/// compatible and the original file is never rewritten.
abstract final class NoteonImagePayload {
  static const String pathKey = 'path';
  static const String widthKey = 'w';

  static String encode({required String path, double? displayWidth}) {
    final normalized = path.trim().replaceAll('\\', '/');
    if (displayWidth == null) {
      return normalized;
    }
    return jsonEncode({
      pathKey: normalized,
      widthKey: displayWidth.round(),
    });
  }

  static ({String path, double? displayWidth}) decode(Object? raw) {
    if (raw is! String) {
      return (path: '', displayWidth: null);
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (path: '', displayWidth: null);
    }
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final path = '${decoded[pathKey] ?? ''}'.trim().replaceAll('\\', '/');
          final w = decoded[widthKey];
          double? width;
          if (w is num) {
            width = w.toDouble();
          } else if (w != null) {
            width = double.tryParse('$w');
          }
          return (path: path, displayWidth: width);
        }
      } catch (_) {
        // Fall through to plain-path handling.
      }
    }
    return (path: trimmed.replaceAll('\\', '/'), displayWidth: null);
  }

  static BlockEmbed embed({required String path, double? displayWidth}) {
    return BlockEmbed.image(encode(path: path, displayWidth: displayWidth));
  }
}
