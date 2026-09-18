import 'dart:convert';

/// Payload for Quill custom embed `noteonAudio`.
///
/// Stored as JSON: `{"path":"audio/….m4a","durationMs":1234}`.
/// Old notes without this embed type are unaffected.
abstract final class NoteonAudioPayload {
  static const String pathKey = 'path';
  static const String durationKey = 'durationMs';

  static String encode({required String path, int? durationMs}) {
    final normalized = path.trim().replaceAll('\\', '/');
    return jsonEncode({
      pathKey: normalized,
      if (durationMs != null && durationMs > 0) durationKey: durationMs,
    });
  }

  static ({String path, int? durationMs}) decode(Object? raw) {
    if (raw is! String) {
      return (path: '', durationMs: null);
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (path: '', durationMs: null);
    }
    if (!trimmed.startsWith('{')) {
      return (path: trimmed.replaceAll('\\', '/'), durationMs: null);
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return (path: '', durationMs: null);
      }
      final path = '${decoded[pathKey] ?? ''}'.trim().replaceAll('\\', '/');
      final d = decoded[durationKey];
      int? durationMs;
      if (d is num) {
        durationMs = d.round();
      } else if (d != null) {
        durationMs = int.tryParse('$d');
      }
      return (path: path, durationMs: durationMs);
    } catch (_) {
      return (path: '', durationMs: null);
    }
  }
}
