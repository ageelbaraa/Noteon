import 'package:flutter/material.dart';

/// Noteon brand palette — teal-forward, calm, practical.
///
/// Light mode uses deep teal for primary actions. Dark mode lifts the primary
/// toward tealLight so controls stay vivid on navy surfaces.
abstract final class AppColors {
  // Brand
  static const Color teal = Color(0xFF0D9488);
  static const Color tealDark = Color(0xFF0F766E);
  static const Color tealDeep = Color(0xFF115E59);
  static const Color tealLight = Color(0xFF5EEAD4);
  static const Color tealMist = Color(0xFFCCFBF1);

  // Neutrals
  static const Color ink = Color(0xFF0F172A);
  static const Color slate = Color(0xFF334155);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color mist = Color(0xFFE2E8F0);

  // Surfaces — light
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceLightAlt = Color(0xFFEEF2F7);
  static const Color surfaceLightElevated = Color(0xFFFFFFFF);

  // Surfaces — dark (navy, not pure black)
  static const Color surfaceDark = Color(0xFF0B1220);
  static const Color surfaceDarkAlt = Color(0xFF152033);
  static const Color surfaceDarkElevated = Color(0xFF1C2A3F);

  static const Color error = Color(0xFFDC2626);
  static const Color errorDark = Color(0xFFF87171);
}

/// Spacing scale used across Noteon layouts.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  static const EdgeInsets screenPadding =
      EdgeInsets.fromLTRB(lg, sm, lg, xl);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
}

/// Corner radius principles for Noteon components.
abstract final class AppRadii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get control => BorderRadius.circular(md);
  static BorderRadius get sheet => BorderRadius.circular(xl);
  static BorderRadius get logoTile => BorderRadius.circular(xl);
}
