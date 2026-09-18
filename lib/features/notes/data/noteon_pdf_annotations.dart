import 'dart:convert';
import 'dart:ui';

/// Overlay annotations for a Noteon PDF (never baked into the PDF bytes).
class NoteonPdfAnnotations {
  const NoteonPdfAnnotations({
    this.version = currentVersion,
    this.pages = const {},
  });

  static const currentVersion = 1;

  final int version;

  /// 0-based page index → strokes on that page.
  final Map<int, List<NoteonPdfStroke>> pages;

  static NoteonPdfAnnotations empty() => const NoteonPdfAnnotations();

  static NoteonPdfAnnotations decode(String raw) {
    if (raw.trim().isEmpty) {
      return empty();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return empty();
      }
      final version = (decoded['version'] as num?)?.toInt() ?? currentVersion;
      final pagesRaw = decoded['pages'];
      final pages = <int, List<NoteonPdfStroke>>{};
      if (pagesRaw is Map) {
        for (final entry in pagesRaw.entries) {
          final pageIndex = int.tryParse('${entry.key}');
          if (pageIndex == null || entry.value is! List) {
            continue;
          }
          pages[pageIndex] = (entry.value as List)
              .whereType<Map>()
              .map((e) => NoteonPdfStroke.fromJson(Map<String, dynamic>.from(e)))
              .where((s) => s.points.isNotEmpty)
              .toList();
        }
      }
      return NoteonPdfAnnotations(version: version, pages: pages);
    } catch (_) {
      return empty();
    }
  }

  String encode() {
    return jsonEncode({
      'version': version,
      'pages': {
        for (final entry in pages.entries)
          if (entry.value.isNotEmpty)
            '${entry.key}': entry.value.map((s) => s.toJson()).toList(),
      },
    });
  }

  NoteonPdfAnnotations copyWithPage(int pageIndex, List<NoteonPdfStroke> strokes) {
    final next = Map<int, List<NoteonPdfStroke>>.from(pages);
    if (strokes.isEmpty) {
      next.remove(pageIndex);
    } else {
      next[pageIndex] = List<NoteonPdfStroke>.from(strokes);
    }
    return NoteonPdfAnnotations(version: version, pages: next);
  }

  List<NoteonPdfStroke> strokesForPage(int pageIndex) =>
      pages[pageIndex] ?? const [];
}

class NoteonPdfStroke {
  const NoteonPdfStroke({
    required this.points,
    required this.color,
    required this.width,
    this.tool = NoteonPdfTool.pen,
  });

  /// Normalized page coordinates (0–1).
  final List<Offset> points;
  final int color;
  final double width;
  final NoteonPdfTool tool;

  factory NoteonPdfStroke.fromJson(Map<String, dynamic> json) {
    final pts = <Offset>[];
    final raw = json['points'];
    if (raw is List) {
      for (final p in raw) {
        if (p is Map) {
          final x = (p['x'] as num?)?.toDouble();
          final y = (p['y'] as num?)?.toDouble();
          if (x != null && y != null) {
            pts.add(Offset(x, y));
          }
        }
      }
    }
    final toolName = '${json['tool'] ?? 'pen'}';
    final tool = NoteonPdfTool.values.firstWhere(
      (t) => t.name == toolName,
      orElse: () => NoteonPdfTool.pen,
    );
    return NoteonPdfStroke(
      points: pts,
      color: (json['color'] as num?)?.toInt() ?? 0xFFE11D48,
      width: (json['width'] as num?)?.toDouble() ?? 0.008,
      tool: tool,
    );
  }

  Map<String, dynamic> toJson() => {
        'tool': tool.name,
        'color': color,
        'width': width,
        'points': [
          for (final p in points) {'x': p.dx, 'y': p.dy},
        ],
      };
}

enum NoteonPdfTool { pen, highlighter, eraser }
