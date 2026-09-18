import 'package:flutter/material.dart';

import '../../../core/settings/app_settings_store.dart';

export '../../../core/settings/app_settings_store.dart' show NotePageBackground;

/// Draws lined or grid paper behind the note editor body.
class NotePageBackgroundPainter extends CustomPainter {
  NotePageBackgroundPainter({
    required this.pattern,
    required this.lineColor,
  });

  final NotePageBackground pattern;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern == NotePageBackground.plain) {
      return;
    }
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    const spacing = 28.0;
    if (pattern == NotePageBackground.lined ||
        pattern == NotePageBackground.grid) {
      for (var y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
    if (pattern == NotePageBackground.grid) {
      for (var x = spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant NotePageBackgroundPainter oldDelegate) {
    return oldDelegate.pattern != pattern || oldDelegate.lineColor != lineColor;
  }
}

/// Wraps [child] with optional lined/grid paper chrome.
class NotePageBackgroundLayer extends StatelessWidget {
  const NotePageBackgroundLayer({
    super.key,
    required this.pattern,
    required this.child,
  });

  final NotePageBackground pattern;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (pattern == NotePageBackground.plain) {
      return child;
    }
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.outlineVariant.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.28 : 0.45,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: NotePageBackgroundPainter(
            pattern: pattern,
            lineColor: lineColor,
          ),
          child: const SizedBox.expand(),
        ),
        child,
      ],
    );
  }
}
