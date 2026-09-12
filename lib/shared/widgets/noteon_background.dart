import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Soft atmospheric backdrop — calm, not decorative.
class NoteonBackground extends StatelessWidget {
  const NoteonBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  AppColors.surfaceDark,
                  Color(0xFF0E1624),
                  AppColors.surfaceDark,
                ]
              : const [
                  Color(0xFFF7FAFC),
                  AppColors.surfaceLight,
                  Color(0xFFF4F8F7),
                ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}
