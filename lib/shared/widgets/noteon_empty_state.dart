import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import 'noteon_logo.dart';

/// Consistent empty-state layout used across Noteon screens.
class NoteonEmptyState extends StatelessWidget {
  const NoteonEmptyState({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.action,
    this.useBrandMark = false,
  });

  /// Optional Material icon. Ignored when [useBrandMark] is true.
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool useBrandMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.normal,
                child: useBrandMark
                    ? const NoteonLogo(
                        key: ValueKey('brand'),
                        size: 72,
                        variant: NoteonLogoVariant.branded,
                      )
                    : icon != null
                        ? Container(
                            key: ValueKey(icon),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(
                                alpha: isDark ? 0.18 : 0.1,
                              ),
                              borderRadius: AppRadii.logoTile,
                            ),
                            child: Icon(
                              icon,
                              size: 36,
                              color: isDark
                                  ? AppColors.tealLight
                                  : AppColors.tealDark,
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Load-failure panel with a retry action.
class NoteonLoadError extends StatelessWidget {
  const NoteonLoadError({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
