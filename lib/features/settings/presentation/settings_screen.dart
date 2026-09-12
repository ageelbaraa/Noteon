import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/noteon_background.dart';
import '../../../shared/widgets/noteon_group_surface.dart';
import '../../../shared/widgets/noteon_logo.dart';
import '../../../shared/widgets/noteon_section_header.dart';

/// Theme, language, and about — preferences persist locally.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: NoteonBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            NoteonSectionHeader(
              title: l10n.appearance,
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            ),
            NoteonGroupSurface(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  child: SegmentedButton<AppThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: AppThemeMode.system,
                        label: Text(l10n.themeSystem),
                        icon: const Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.light,
                        label: Text(l10n.themeLight),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        label: Text(l10n.themeDark),
                        icon: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (value) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setMode(value.first);
                    },
                  ),
                ),
              ],
            ),
            NoteonSectionHeader(
              title: l10n.language,
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            NoteonGroupSurface(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'system',
                        label: Text(l10n.languageSystem),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text(l10n.languageEnglish),
                      ),
                      ButtonSegment(
                        value: 'ar',
                        label: Text(l10n.languageArabic),
                      ),
                    ],
                    selected: {
                      locale == null ? 'system' : locale.languageCode,
                    },
                    onSelectionChanged: (value) {
                      final code = value.first;
                      ref.read(localeProvider.notifier).setLocale(
                            code == 'system' ? null : Locale(code),
                          );
                    },
                  ),
                ),
              ],
            ),
            NoteonSectionHeader(
              title: l10n.about,
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            NoteonGroupSurface(
              children: [
                Padding(
                  padding: AppSpacing.cardPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.2
                                : 0.1,
                          ),
                          borderRadius: AppRadii.control,
                        ),
                        child: const NoteonLogo(
                          size: 44,
                          variant: NoteonLogoVariant.branded,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.appName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.aboutDescription,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                              ),
                              child: Text(
                                l10n.versionLabel(AppConstants.appVersion),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
