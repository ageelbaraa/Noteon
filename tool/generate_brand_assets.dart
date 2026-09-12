// Generates production Noteon brand PNGs (full-bleed, no pre-rounded mask).
// Run: dart run tool/generate_brand_assets.dart

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  final root = Directory.current.path;
  final outDir = Directory(p.join(root, 'assets', 'branding'));
  outDir.createSync(recursive: true);

  final icon = _drawIcon(1024);
  File(p.join(outDir.path, 'noteon_icon.png'))
      .writeAsBytesSync(img.encodePng(icon));

  final mark = _drawMarkOnly(1024);
  File(p.join(outDir.path, 'noteon_mark.png'))
      .writeAsBytesSync(img.encodePng(mark));

  final splash = _drawSplashLogo(512);
  File(p.join(outDir.path, 'noteon_splash_logo.png'))
      .writeAsBytesSync(img.encodePng(splash));

  stdout.writeln('Wrote brand assets to ${outDir.path}');
}

img.Image _drawIcon(int size) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(0x0D, 0x94, 0x88));
  _paintMark(
    image,
    size,
    markColor: img.ColorRgb8(255, 255, 255),
    cutoutColor: img.ColorRgb8(0x0D, 0x94, 0x88),
  );
  return image;
}

img.Image _drawMarkOnly(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  _paintMark(
    image,
    size,
    markColor: img.ColorRgba8(0x0D, 0x94, 0x88, 255),
    cutoutColor: img.ColorRgba8(0, 0, 0, 0),
  );
  return image;
}

img.Image _drawSplashLogo(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  final pad = (size * 0.06).round();
  final radius = size * 0.22;
  img.fillRect(
    image,
    x1: pad,
    y1: pad,
    x2: size - pad,
    y2: size - pad,
    radius: radius,
    color: img.ColorRgba8(0x0D, 0x94, 0x88, 255),
  );
  _paintMark(
    image,
    size,
    markColor: img.ColorRgba8(255, 255, 255, 255),
    cutoutColor: img.ColorRgba8(0x0D, 0x94, 0x88, 255),
    inset: 0.10,
  );
  return image;
}

void _paintMark(
  img.Image image,
  int size, {
  required img.Color markColor,
  required img.Color cutoutColor,
  double inset = 0.0,
}) {
  final s = size.toDouble();
  final margin = s * (0.22 + inset);

  final noteLeft = margin;
  final noteTop = margin * 1.02;
  final noteRight = s - margin * 1.12;
  final noteBottom = s - margin;
  final noteRadius = s * 0.055;

  img.fillRect(
    image,
    x1: noteLeft.round(),
    y1: noteTop.round(),
    x2: noteRight.round(),
    y2: noteBottom.round(),
    radius: noteRadius,
    color: markColor,
  );

  // Dog-ear cutout + fold.
  final ear = s * 0.13;
  for (var y = noteTop.round(); y < (noteTop + ear).round(); y++) {
    for (var x = (noteRight - ear).round(); x < noteRight.round(); x++) {
      final dx = x - (noteRight - ear);
      final dy = y - noteTop;
      if (dx + dy > ear) {
        continue;
      }
      if (x >= 0 && y >= 0 && x < size && y < size) {
        image.setPixel(x, y, cutoutColor);
      }
    }
  }

  final fold = _mix(markColor, cutoutColor, 0.22);
  img.fillPolygon(
    image,
    vertices: [
      img.Point((noteRight - ear).round(), noteTop.round()),
      img.Point(noteRight.round(), (noteTop + ear).round()),
      img.Point((noteRight - ear).round(), (noteTop + ear).round()),
    ],
    color: fold,
  );

  // Content lines as cutouts.
  final lineLeft = noteLeft + s * 0.09;
  final lineRight = noteRight - s * 0.2;
  final lineH = (s * 0.032).clamp(3.0, 12.0);
  final y1 = noteTop + s * 0.2;
  final y2 = noteTop + s * 0.3;
  img.fillRect(
    image,
    x1: lineLeft.round(),
    y1: y1.round(),
    x2: lineRight.round(),
    y2: (y1 + lineH).round(),
    radius: lineH / 2,
    color: cutoutColor,
  );
  img.fillRect(
    image,
    x1: lineLeft.round(),
    y1: y2.round(),
    x2: (lineRight - s * 0.1).round(),
    y2: (y2 + lineH).round(),
    radius: lineH / 2,
    color: cutoutColor,
  );

  // Bold geometric ink stroke (writing mark / abstract N).
  final stroke = (s * 0.07).clamp(8.0, 30.0);
  final p1x = noteLeft + s * 0.12;
  final p1y = noteBottom - s * 0.08;
  final p2x = noteLeft + s * 0.32;
  final p2y = noteTop + s * 0.42;
  final p3x = noteLeft + s * 0.52;
  final p3y = noteBottom - s * 0.16;
  final p4x = noteRight - s * 0.06;
  final p4y = noteTop + s * 0.38;

  _drawSmoothStroke(
    image,
    [
      [p1x, p1y],
      [p2x, p2y],
      [p3x, p3y],
      [p4x, p4y],
    ],
    stroke,
    cutoutColor,
  );
}

void _drawSmoothStroke(
  img.Image image,
  List<List<double>> points,
  double thickness,
  img.Color color,
) {
  final radius = (thickness / 2).round().clamp(2, 48);
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final dx = b[0] - a[0];
    final dy = b[1] - a[1];
    final dist = (dx * dx + dy * dy);
    final steps = (dist > 0 ? (sqrt(dist) / 1.5).ceil() : 1).clamp(1, 400);
    for (var s = 0; s <= steps; s++) {
      final t = s / steps;
      final x = (a[0] + dx * t).round();
      final y = (a[1] + dy * t).round();
      img.fillCircle(image, x: x, y: y, radius: radius, color: color);
    }
  }
}

double sqrt(double v) {
  // Local sqrt to avoid dart:math Point clash in this script.
  if (v <= 0) {
    return 0;
  }
  var x = v;
  for (var i = 0; i < 12; i++) {
    x = 0.5 * (x + v / x);
  }
  return x;
}

img.Color _mix(img.Color a, img.Color b, double t) {
  final w = t.clamp(0.0, 1.0);
  int mix(num x, num y) => (x * (1 - w) + y * w).round().clamp(0, 255);
  return img.ColorRgba8(
    mix(a.r, b.r),
    mix(a.g, b.g),
    mix(a.b, b.b),
    mix(a.a, b.a),
  );
}
