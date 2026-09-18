import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Payload for Quill custom embed `noteonInk` (vector strokes + PNG preview).
///
/// Strokes live under `ink/{id}.json`; preview under `ink/{id}.png`.
/// Legacy raster sketches (`BlockEmbed.image` under `sketches/`) are untouched.
abstract final class NoteonInkPayload {
  static const String idKey = 'id';
  static const String strokesKey = 'strokes';
  static const String previewKey = 'preview';
  static const String widthKey = 'w';

  static String encode({
    required String id,
    required String strokesPath,
    required String previewPath,
    double? displayWidth,
  }) {
    return jsonEncode({
      idKey: id.trim(),
      strokesKey: strokesPath.trim().replaceAll('\\', '/'),
      previewKey: previewPath.trim().replaceAll('\\', '/'),
      if (displayWidth != null) widthKey: displayWidth.round(),
    });
  }

  static NoteonInkData decode(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return NoteonInkData.empty;
    }
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map) {
        return NoteonInkData.empty;
      }
      final id = '${decoded[idKey] ?? ''}'.trim();
      final strokes =
          '${decoded[strokesKey] ?? ''}'.trim().replaceAll('\\', '/');
      final preview =
          '${decoded[previewKey] ?? ''}'.trim().replaceAll('\\', '/');
      final w = decoded[widthKey];
      double? width;
      if (w is num) {
        width = w.toDouble();
      } else if (w != null) {
        width = double.tryParse('$w');
      }
      if (id.isEmpty || strokes.isEmpty || preview.isEmpty) {
        return NoteonInkData.empty;
      }
      return NoteonInkData(
        id: id,
        strokesPath: strokes,
        previewPath: preview,
        displayWidth: width,
      );
    } catch (_) {
      return NoteonInkData.empty;
    }
  }
}

/// Decoded ink embed fields.
class NoteonInkData {
  const NoteonInkData({
    required this.id,
    required this.strokesPath,
    required this.previewPath,
    this.displayWidth,
  });

  static const empty = NoteonInkData(
    id: '',
    strokesPath: '',
    previewPath: '',
  );

  final String id;
  final String strokesPath;
  final String previewPath;
  final double? displayWidth;

  bool get isEmpty => id.isEmpty || strokesPath.isEmpty || previewPath.isEmpty;

  List<String> get mediaPaths =>
      isEmpty ? const [] : [strokesPath, previewPath];

  NoteonInkData copyWith({double? displayWidth}) {
    return NoteonInkData(
      id: id,
      strokesPath: strokesPath,
      previewPath: previewPath,
      displayWidth: displayWidth ?? this.displayWidth,
    );
  }

  String toJsonString() => NoteonInkPayload.encode(
        id: id,
        strokesPath: strokesPath,
        previewPath: previewPath,
        displayWidth: displayWidth,
      );
}

/// Quill custom embed type for vector ink drawings.
class NoteonInkBlockEmbed extends CustomBlockEmbed {
  const NoteonInkBlockEmbed(String data) : super(embedType, data);

  static const String embedType = 'noteonInk';

  factory NoteonInkBlockEmbed.fromData(NoteonInkData data) {
    return NoteonInkBlockEmbed(data.toJsonString());
  }

  NoteonInkData get inkData => NoteonInkPayload.decode(data);

  static NoteonInkData? tryParseEmbeddable(Embeddable embeddable) {
    try {
      if (embeddable.type == embedType) {
        final decoded = NoteonInkPayload.decode('${embeddable.data}');
        return decoded.isEmpty ? null : decoded;
      }
      if (embeddable.type == BlockEmbed.customType) {
        final custom = CustomBlockEmbed.fromJsonString('${embeddable.data}');
        if (custom.type == embedType) {
          final decoded = NoteonInkPayload.decode(custom.data);
          return decoded.isEmpty ? null : decoded;
        }
      }
    } catch (_) {
      // Ignore malformed embeds.
    }
    return null;
  }
}
