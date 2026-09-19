import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Comfortable Quill styles: readable body size with tighter chrome spacing.
///
/// Body stays near the Material default (16) — density comes from spacing,
/// not smaller type. Text color is forced to [ColorScheme.onSurface] so the
/// editor never inherits an accidental theme/error color as the default ink.
DefaultStyles noteEditorCompactStyles(BuildContext context) {
  final theme = Theme.of(context);
  final ink = theme.colorScheme.onSurface;

  const hSpace = HorizontalSpacing(0, 0);
  final paragraphStyle = TextStyle(
    fontSize: 16,
    height: 1.3,
    color: ink,
    decoration: TextDecoration.none,
  );

  DefaultTextBlockStyle heading(
    double size,
    double height,
    VerticalSpacing spacing,
  ) {
    return DefaultTextBlockStyle(
      TextStyle(
        fontSize: size,
        height: height,
        color: ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        decoration: TextDecoration.none,
      ),
      hSpace,
      spacing,
      VerticalSpacing.zero,
      null,
    );
  }

  return DefaultStyles.getInstance(context).merge(
    DefaultStyles(
      // Used by Quill when resolving inline color decorations.
      color: ink,
      paragraph: DefaultTextBlockStyle(
        paragraphStyle,
        hSpace,
        const VerticalSpacing(2, 0),
        VerticalSpacing.zero,
        null,
      ),
      placeHolder: DefaultTextBlockStyle(
        paragraphStyle.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        hSpace,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      h1: heading(28, 1.12, const VerticalSpacing(12, 2)),
      h2: heading(24, 1.14, const VerticalSpacing(10, 2)),
      h3: heading(20, 1.16, const VerticalSpacing(8, 2)),
      h4: heading(17, 1.18, const VerticalSpacing(6, 2)),
      h5: heading(16, 1.2, const VerticalSpacing(4, 0)),
      h6: heading(16, 1.22, const VerticalSpacing(4, 0)),
      lists: DefaultListBlockStyle(
        paragraphStyle,
        hSpace,
        const VerticalSpacing(2, 0),
        const VerticalSpacing(0, 4),
        null,
        null,
      ),
    ),
  );
}
