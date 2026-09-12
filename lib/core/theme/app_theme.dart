import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_motion.dart';

/// Builds light and dark [ThemeData] for Noteon.
abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.teal,
      onPrimary: Colors.white,
      primaryContainer: AppColors.tealMist,
      onPrimaryContainer: AppColors.tealDeep,
      secondary: AppColors.slate,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.mist,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.tealDark,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.slateMuted,
      outline: AppColors.mist,
      outlineVariant: const Color(0xFFCBD5E1),
      surfaceContainerHighest: AppColors.surfaceLightAlt,
      surfaceContainerHigh: AppColors.surfaceLightElevated,
      surfaceContainer: AppColors.surfaceLightElevated,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.surfaceLight,
      inversePrimary: AppColors.tealLight,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return _base(colorScheme, Brightness.light);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.tealLight,
      onPrimary: AppColors.surfaceDark,
      primaryContainer: AppColors.tealDeep,
      onPrimaryContainer: AppColors.tealMist,
      secondary: const Color(0xFF94A3B8),
      onSecondary: AppColors.surfaceDark,
      secondaryContainer: AppColors.surfaceDarkElevated,
      onSecondaryContainer: const Color(0xFFE2E8F0),
      tertiary: AppColors.teal,
      onTertiary: Colors.white,
      error: AppColors.errorDark,
      onError: AppColors.surfaceDark,
      surface: AppColors.surfaceDark,
      onSurface: const Color(0xFFE8EEF7),
      onSurfaceVariant: const Color(0xFF94A3B8),
      outline: const Color(0xFF334155),
      outlineVariant: const Color(0xFF243044),
      surfaceContainerHighest: AppColors.surfaceDarkElevated,
      surfaceContainerHigh: AppColors.surfaceDarkAlt,
      surfaceContainer: AppColors.surfaceDarkAlt,
      inverseSurface: AppColors.surfaceLight,
      onInverseSurface: AppColors.ink,
      inversePrimary: AppColors.teal,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return _base(colorScheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme colorScheme, Brightness brightness) {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    final refinedText = textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        height: 1.2,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
      ),
      titleSmall: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.45),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    final isLight = brightness == Brightness.light;
    final elevated = isLight
        ? AppColors.surfaceLightElevated
        : AppColors.surfaceDarkElevated;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: refinedText,
      scaffoldBackgroundColor:
          isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor:
            isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: refinedText.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: elevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.horizontal(
            end: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor:
            isLight ? AppColors.surfaceLightElevated : AppColors.surfaceDarkAlt,
        indicatorColor: AppColors.teal.withValues(alpha: isLight ? 0.14 : 0.26),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return refinedText.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (isLight ? AppColors.tealDark : AppColors.tealLight)
                : colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected
                ? (isLight ? AppColors.tealDark : AppColors.tealLight)
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: elevated,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight
            ? AppColors.teal.withValues(alpha: 0.08)
            : AppColors.teal.withValues(alpha: 0.18),
        selectedColor: AppColors.teal.withValues(alpha: 0.22),
        disabledColor: colorScheme.surfaceContainerHighest,
        labelStyle: refinedText.labelMedium,
        secondaryLabelStyle: refinedText.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
        side: BorderSide.none,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.sheet),
        titleTextStyle: refinedText.titleLarge,
        contentTextStyle: refinedText.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
          textStyle: refinedText.labelLarge,
          animationDuration: AppMotion.fast,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isLight ? AppColors.tealDark : AppColors.tealLight,
          minimumSize: const Size(48, 48),
          side: BorderSide(
            color: AppColors.teal.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isLight ? AppColors.tealDark : AppColors.tealLight,
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.comfortable,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadii.control),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? AppColors.ink : AppColors.surfaceDarkElevated,
        contentTextStyle: refinedText.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
        iconColor: AppColors.teal,
        selectedColor: isLight ? AppColors.tealDark : AppColors.tealLight,
        selectedTileColor: AppColors.teal.withValues(alpha: isLight ? 0.1 : 0.18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        minVerticalPadding: 12,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: elevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? AppColors.surfaceLightAlt
            : AppColors.surfaceDarkElevated,
        border: OutlineInputBorder(
          borderRadius: AppRadii.control,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.control,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.control,
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: refinedText.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.teal,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: colorScheme.onSurface,
        ),
      ),
    );
  }
}
