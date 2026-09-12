import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Vector Noteon mark: folded note + content lines + ink stroke.
///
/// Scales cleanly from toolbar size to hero empty states. Prefer this over
/// raster assets inside Flutter UI so RTL/theme tinting stays crisp.
class NoteonLogo extends StatelessWidget {
  const NoteonLogo({
    super.key,
    this.size = 40,
    this.variant = NoteonLogoVariant.branded,
  });

  final double size;
  final NoteonLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    late final Color tile;
    late final Color mark;
    late final Color cutout;
    late final Color fold;
    final bool showTile;

    switch (variant) {
      case NoteonLogoVariant.branded:
        showTile = true;
        tile = AppColors.teal;
        mark = Colors.white;
        cutout = AppColors.teal;
        fold = AppColors.tealMist.withValues(alpha: 0.85);
      case NoteonLogoVariant.onSurface:
        showTile = true;
        tile = isDark
            ? AppColors.teal.withValues(alpha: 0.22)
            : AppColors.teal.withValues(alpha: 0.12);
        mark = isDark ? AppColors.tealLight : AppColors.teal;
        cutout = tile;
        fold = isDark
            ? AppColors.teal.withValues(alpha: 0.45)
            : AppColors.tealMist;
      case NoteonLogoVariant.mono:
        showTile = false;
        tile = Colors.transparent;
        mark = isDark ? AppColors.tealLight : AppColors.teal;
        cutout = Colors.transparent;
        fold = mark.withValues(alpha: 0.35);
    }

    return Semantics(
      label: 'Noteon',
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: showTile ? tile : null,
            borderRadius: showTile ? AppRadii.logoTile : null,
          ),
          child: CustomPaint(
            painter: _NoteonMarkPainter(
              mark: mark,
              cutout: cutout,
              fold: fold,
              punchCutout: showTile,
            ),
          ),
        ),
      ),
    );
  }
}

enum NoteonLogoVariant {
  /// Teal tile with white mark (splash, about, hero).
  branded,

  /// Soft teal wash with teal mark (empty states).
  onSurface,

  /// Mark only, no tile.
  mono,
}

class _NoteonMarkPainter extends CustomPainter {
  const _NoteonMarkPainter({
    required this.mark,
    required this.cutout,
    required this.fold,
    required this.punchCutout,
  });

  final Color mark;
  final Color cutout;
  final Color fold;
  final bool punchCutout;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final inset = s * 0.22;
    final noteRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(inset, inset * 1.02, s - inset * 1.1, s - inset),
      Radius.circular(s * 0.055),
    );

    canvas.drawRRect(noteRect, Paint()..color = mark);

    final ear = s * 0.13;
    if (punchCutout) {
      final earPath = Path()
        ..moveTo(noteRect.right - ear, noteRect.top)
        ..lineTo(noteRect.right, noteRect.top)
        ..lineTo(noteRect.right, noteRect.top + ear)
        ..close();
      canvas.drawPath(earPath, Paint()..color = cutout);
    }

    final foldPath = Path()
      ..moveTo(noteRect.right - ear, noteRect.top)
      ..lineTo(noteRect.right, noteRect.top + ear)
      ..lineTo(noteRect.right - ear, noteRect.top + ear)
      ..close();
    canvas.drawPath(foldPath, Paint()..color = fold);

    final linePaint = Paint()..color = punchCutout ? cutout : fold;
    final lineLeft = noteRect.left + s * 0.09;
    final lineRight = noteRect.right - s * 0.2;
    final lineH = (s * 0.032).clamp(2.0, 8.0);
    final y1 = noteRect.top + s * 0.2;
    final y2 = noteRect.top + s * 0.3;
    canvas.drawRRect(
      RRect.fromLTRBR(
        lineLeft,
        y1,
        lineRight,
        y1 + lineH,
        Radius.circular(lineH),
      ),
      linePaint,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        lineLeft,
        y2,
        lineRight - s * 0.1,
        y2 + lineH,
        Radius.circular(lineH),
      ),
      linePaint,
    );

    final stroke = Paint()
      ..color = punchCutout ? cutout : fold
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.07).clamp(3.0, 14.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(noteRect.left + s * 0.12, noteRect.bottom - s * 0.08)
      ..lineTo(noteRect.left + s * 0.32, noteRect.top + s * 0.42)
      ..lineTo(noteRect.left + s * 0.52, noteRect.bottom - s * 0.16)
      ..lineTo(noteRect.right - s * 0.06, noteRect.top + s * 0.38);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _NoteonMarkPainter oldDelegate) {
    return oldDelegate.mark != mark ||
        oldDelegate.cutout != cutout ||
        oldDelegate.fold != fold ||
        oldDelegate.punchCutout != punchCutout;
  }
}
