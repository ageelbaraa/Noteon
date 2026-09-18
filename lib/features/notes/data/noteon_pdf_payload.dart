import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Payload for Quill custom embed `noteonPdf`.
///
/// PDF source: `pdfs/{id}.pdf` (immutable after import).
/// Annotations: `pdfs/{id}.ann.json` (mutable overlay only).
abstract final class NoteonPdfPayload {
  static const String idKey = 'id';
  static const String pdfKey = 'pdf';
  static const String annotationsKey = 'annotations';
  static const String widthKey = 'w';
  static const String titleKey = 'title';

  static String encode({
    required String id,
    required String pdfPath,
    required String annotationsPath,
    String? title,
    double? displayWidth,
  }) {
    return jsonEncode({
      idKey: id.trim(),
      pdfKey: pdfPath.trim().replaceAll('\\', '/'),
      annotationsKey: annotationsPath.trim().replaceAll('\\', '/'),
      if (title != null && title.trim().isNotEmpty) titleKey: title.trim(),
      if (displayWidth != null) widthKey: displayWidth.round(),
    });
  }

  static NoteonPdfData decode(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return NoteonPdfData.empty;
    }
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map) {
        return NoteonPdfData.empty;
      }
      final id = '${decoded[idKey] ?? ''}'.trim();
      final pdf = '${decoded[pdfKey] ?? ''}'.trim().replaceAll('\\', '/');
      final ann =
          '${decoded[annotationsKey] ?? ''}'.trim().replaceAll('\\', '/');
      final title = '${decoded[titleKey] ?? ''}'.trim();
      final w = decoded[widthKey];
      double? width;
      if (w is num) {
        width = w.toDouble();
      } else if (w != null) {
        width = double.tryParse('$w');
      }
      if (id.isEmpty || pdf.isEmpty || ann.isEmpty) {
        return NoteonPdfData.empty;
      }
      return NoteonPdfData(
        id: id,
        pdfPath: pdf,
        annotationsPath: ann,
        title: title.isEmpty ? null : title,
        displayWidth: width,
      );
    } catch (_) {
      return NoteonPdfData.empty;
    }
  }
}

class NoteonPdfData {
  const NoteonPdfData({
    required this.id,
    required this.pdfPath,
    required this.annotationsPath,
    this.title,
    this.displayWidth,
  });

  static const empty = NoteonPdfData(
    id: '',
    pdfPath: '',
    annotationsPath: '',
  );

  final String id;
  final String pdfPath;
  final String annotationsPath;
  final String? title;
  final double? displayWidth;

  bool get isEmpty => id.isEmpty || pdfPath.isEmpty || annotationsPath.isEmpty;

  List<String> get mediaPaths =>
      isEmpty ? const [] : [pdfPath, annotationsPath];

  NoteonPdfData copyWith({String? title, double? displayWidth}) {
    return NoteonPdfData(
      id: id,
      pdfPath: pdfPath,
      annotationsPath: annotationsPath,
      title: title ?? this.title,
      displayWidth: displayWidth ?? this.displayWidth,
    );
  }

  String toJsonString() => NoteonPdfPayload.encode(
        id: id,
        pdfPath: pdfPath,
        annotationsPath: annotationsPath,
        title: title,
        displayWidth: displayWidth,
      );
}

class NoteonPdfBlockEmbed extends CustomBlockEmbed {
  const NoteonPdfBlockEmbed(String data) : super(embedType, data);

  static const String embedType = 'noteonPdf';

  factory NoteonPdfBlockEmbed.fromData(NoteonPdfData data) {
    return NoteonPdfBlockEmbed(data.toJsonString());
  }

  NoteonPdfData get pdfData => NoteonPdfPayload.decode(data);

  static NoteonPdfData? tryParseEmbeddable(Embeddable embeddable) {
    try {
      if (embeddable.type == embedType) {
        final decoded = NoteonPdfPayload.decode('${embeddable.data}');
        return decoded.isEmpty ? null : decoded;
      }
      if (embeddable.type == BlockEmbed.customType) {
        final custom = CustomBlockEmbed.fromJsonString('${embeddable.data}');
        if (custom.type == embedType) {
          final decoded = NoteonPdfPayload.decode(custom.data);
          return decoded.isEmpty ? null : decoded;
        }
      }
    } catch (_) {}
    return null;
  }
}
