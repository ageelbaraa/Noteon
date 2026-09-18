import 'dart:convert';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_drawing_board/paint_contents.dart';

/// Serialize / restore flutter_drawing_board strokes for Noteon ink embeds.
abstract final class NoteonInkStrokeCodec {
  /// Active strokes only (excludes undone history past [currentIndex]).
  static List<Map<String, dynamic>> exportActive({
    required List<PaintContent> history,
    required int currentIndex,
  }) {
    final end = currentIndex.clamp(0, history.length);
    return history.take(end).map((c) => c.toJson()).toList(growable: false);
  }

  static String encodeJsonList(List<Map<String, dynamic>> strokes) {
    return jsonEncode(strokes);
  }

  static List<Map<String, dynamic>> decodeJsonList(String raw) {
    if (raw.trim().isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static List<PaintContent> contentsFromJsonList(
    List<Map<String, dynamic>> strokes,
  ) {
    final out = <PaintContent>[];
    for (final map in strokes) {
      final content = contentFromJson(map);
      if (content != null) {
        out.add(content);
      }
    }
    return out;
  }

  static PaintContent? contentFromJson(Map<String, dynamic> data) {
    final type = '${data['type'] ?? ''}';
    try {
      switch (type) {
        case 'SimpleLine':
          return SimpleLine.fromJson(data);
        case 'Eraser':
          return Eraser.fromJson(data);
        case 'SmoothLine':
          return SmoothLine.fromJson(data);
        case 'StraightLine':
          return StraightLine.fromJson(data);
        case 'Rectangle':
          return Rectangle.fromJson(data);
        case 'Circle':
          return Circle.fromJson(data);
        case 'EmptyContent':
          return EmptyContent.fromJson(data);
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// True when any sample point of the stroke lies inside [polygon].
  static bool strokeIntersectsPolygon(
    Map<String, dynamic> stroke,
    List<Offset> polygon,
  ) {
    if (polygon.length < 3) {
      return false;
    }
    for (final point in samplePoints(stroke)) {
      if (_pointInPolygon(point, polygon)) {
        return true;
      }
    }
    return false;
  }

  static List<Offset> samplePoints(Map<String, dynamic> stroke) {
    final points = <Offset>[];
    final rawPoints = stroke['points'];
    if (rawPoints is List) {
      for (final p in rawPoints) {
        if (p is Map) {
          final dx = (p['dx'] as num?)?.toDouble();
          final dy = (p['dy'] as num?)?.toDouble();
          if (dx != null && dy != null) {
            points.add(Offset(dx, dy));
          }
        }
      }
    }
    final path = stroke['path'];
    if (path is Map) {
      final steps = path['steps'] ?? path['path'];
      if (steps is List) {
        for (final step in steps) {
          if (step is Map) {
            final x = (step['x'] as num?)?.toDouble() ??
                (step['dx'] as num?)?.toDouble();
            final y = (step['y'] as num?)?.toDouble() ??
                (step['dy'] as num?)?.toDouble();
            if (x != null && y != null) {
              points.add(Offset(x, y));
            }
          }
        }
      }
    }
    // Start/end for shapes
    for (final key in ['startPoint', 'endPoint', 'center']) {
      final p = stroke[key];
      if (p is Map) {
        final dx = (p['dx'] as num?)?.toDouble();
        final dy = (p['dy'] as num?)?.toDouble();
        if (dx != null && dy != null) {
          points.add(Offset(dx, dy));
        }
      }
    }
    return points;
  }

  /// Translates stroke JSON by [delta] (deep-copies maps).
  static Map<String, dynamic> translateStroke(
    Map<String, dynamic> stroke,
    Offset delta,
  ) {
    final copy = jsonDecode(jsonEncode(stroke)) as Map<String, dynamic>;
    _translateOffsetsInPlace(copy, delta);
    return copy;
  }

  static void _translateOffsetsInPlace(
    Object? node,
    Offset delta,
  ) {
    if (node is Map) {
      if (node.containsKey('dx') && node.containsKey('dy')) {
        final dx = (node['dx'] as num?)?.toDouble();
        final dy = (node['dy'] as num?)?.toDouble();
        if (dx != null && dy != null) {
          node['dx'] = dx + delta.dx;
          node['dy'] = dy + delta.dy;
        }
      }
      if (node.containsKey('x') && node.containsKey('y')) {
        final x = (node['x'] as num?)?.toDouble();
        final y = (node['y'] as num?)?.toDouble();
        if (x != null && y != null) {
          node['x'] = x + delta.dx;
          node['y'] = y + delta.dy;
        }
      }
      for (final value in node.values) {
        _translateOffsetsInPlace(value, delta);
      }
    } else if (node is List) {
      for (final item in node) {
        _translateOffsetsInPlace(item, delta);
      }
    }
  }

  static bool _pointInPolygon(Offset point, List<Offset> polygon) {
    // Ray casting
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      final intersect = ((pi.dy > point.dy) != (pj.dy > point.dy)) &&
          (point.dx <
              (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy + 0.0) +
                  pi.dx);
      if (intersect) {
        inside = !inside;
      }
    }
    return inside;
  }
}
