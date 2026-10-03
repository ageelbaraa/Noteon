import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/noteon_background.dart';
import '../../../shared/widgets/noteon_group_surface.dart';
import '../../../shared/widgets/noteon_logo.dart';
import '../../../shared/widgets/noteon_section_header.dart';
import '../../app_lock/presentation/app_lock_section.dart';
import '../../transfer/presentation/backup_transfer_actions.dart';

/// Theme, language, profile, and about — preferences persist locally.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final displayName = ref.watch(displayNameProvider);
    final packageInfo = ref.watch(packageInfoProvider).valueOrNull;
    final hasName = displayName.trim().isNotEmpty;

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
              title: l10n.profile,
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            ),
            NoteonGroupSurface(
              children: [
                NoteonGroupTile(
                  leading: Icon(
                    hasName
                        ? Icons.person_rounded
                        : Icons.person_add_alt_1_rounded,
                  ),
                  title: hasName ? displayName : l10n.displayNameEmpty,
                  subtitle: l10n.displayName,
                  trailing: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _editDisplayName(context, ref),
                ),
              ],
            ),
            NoteonSectionHeader(
              title: l10n.appearance,
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            NoteonGroupSurface(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 340;
                      return SegmentedButton<AppThemeMode>(
                        showSelectedIcon: true,
                        segments: [
                          ButtonSegment(
                            value: AppThemeMode.system,
                            label: compact ? null : Text(l10n.themeSystem),
                            icon: const Icon(Icons.brightness_auto_outlined),
                            tooltip: l10n.themeSystem,
                          ),
                          ButtonSegment(
                            value: AppThemeMode.light,
                            label: compact ? null : Text(l10n.themeLight),
                            icon: const Icon(Icons.light_mode_outlined),
                            tooltip: l10n.themeLight,
                          ),
                          ButtonSegment(
                            value: AppThemeMode.dark,
                            label: compact ? null : Text(l10n.themeDark),
                            icon: const Icon(Icons.dark_mode_outlined),
                            tooltip: l10n.themeDark,
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (value) {
                          ref
                              .read(themeModeProvider.notifier)
                              .setMode(value.first);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            NoteonSectionHeader(
              title: l10n.notePageBackground,
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            NoteonGroupSurface(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 340;
                      final pageBg = ref.watch(notePageBackgroundProvider);
                      return SegmentedButton<NotePageBackground>(
                        showSelectedIcon: true,
                        segments: [
                          ButtonSegment(
                            value: NotePageBackground.plain,
                            label: compact
                                ? null
                                : Text(l10n.notePageBackgroundPlain),
                            icon: const Icon(Icons.crop_square_outlined),
                            tooltip: l10n.notePageBackgroundPlain,
                          ),
                          ButtonSegment(
                            value: NotePageBackground.lined,
                            label: compact
                                ? null
                                : Text(l10n.notePageBackgroundLined),
                            icon: const Icon(Icons.notes_rounded),
                            tooltip: l10n.notePageBackgroundLined,
                          ),
                          ButtonSegment(
                            value: NotePageBackground.grid,
                            label: compact
                                ? null
                                : Text(l10n.notePageBackgroundGrid),
                            icon: const Icon(Icons.grid_on_rounded),
                            tooltip: l10n.notePageBackgroundGrid,
                          ),
                        ],
                        selected: {pageBg},
                        onSelectionChanged: (value) {
                          ref
                              .read(notePageBackgroundProvider.notifier)
                              .setBackground(value.first);
                        },
                      );
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 340;
                      final button = SegmentedButton<String>(
                        showSelectedIcon: true,
                        segments: [
                          ButtonSegment(
                            value: 'system',
                            label: Text(l10n.languageSystem),
                            tooltip: l10n.languageSystem,
                          ),
                          ButtonSegment(
                            value: 'en',
                            label: Text(l10n.languageEnglish),
                            tooltip: l10n.languageEnglish,
                          ),
                          ButtonSegment(
                            value: 'ar',
                            label: Text(l10n.languageArabic),
                            tooltip: l10n.languageArabic,
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
                      );
                      if (!compact) {
                        return button;
                      }
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: SizedBox(width: 340, child: button),
                      );
                    },
                  ),
                ),
              ],
            ),
            NoteonSectionHeader(
              title: l10n.backupTransfer,
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            NoteonGroupSurface(
              children: [
                NoteonGroupTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: l10n.backupExportEncrypted,
                  subtitle: l10n.backupExportEncryptedSubtitle,
                  onTap: () => BackupTransferActions.exportBackup(context, ref),
                ),
                NoteonGroupTile(
                  leading: const Icon(Icons.download_outlined),
                  title: l10n.backupImportEncrypted,
                  subtitle: l10n.backupImportEncryptedSubtitle,
                  onTap: () => BackupTransferActions.importBackup(context, ref),
                ),
                NoteonGroupTile(
                  leading: const Icon(Icons.qr_code_2_outlined),
                  title: l10n.nearbySendTitle,
                  subtitle: l10n.nearbySendSubtitle,
                  onTap: () => BackupTransferActions.sendNearby(context, ref),
                ),
                NoteonGroupTile(
                  leading: const Icon(Icons.qr_code_scanner_outlined),
                  title: l10n.nearbyReceiveTitle,
                  subtitle: l10n.nearbyReceiveSubtitle,
                  onTap: () =>
                      BackupTransferActions.receiveNearby(context, ref),
                ),
              ],
            ),
            NoteonSectionHeader(
              title: l10n.appLockSection,
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            const AppLockSection(),
            NoteonSectionHeader(
              title: l10n.privacy,
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            NoteonGroupSurface(
              children: [
                NoteonGroupTile(
                  leading: const Icon(Icons.document_scanner_outlined),
                  title: l10n.privacyOcrTitle,
                  subtitle: l10n.privacyOcrSubtitle,
                ),
                NoteonGroupTile(
                  leading: const Icon(Icons.short_text_rounded),
                  title: l10n.privacyAssistTitle,
                  subtitle: l10n.privacyAssistSubtitle,
                ),
                NoteonGroupTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: l10n.privacyExportTitle,
                  subtitle: l10n.privacyExportSubtitle,
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
                                packageInfo == null
                                    ? ''
                                    : l10n.versionBuildLabel(
                                        packageInfo.version,
                                        packageInfo.buildNumber,
                                      ),
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

Future<void> _editDisplayName(BuildContext context, WidgetRef ref) async {
  final current = ref.read(displayNameProvider);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _EditDisplayNameDialog(initialName: current),
  );
  if (name == null || !context.mounted) {
    return;
  }
  await ref.read(displayNameProvider.notifier).setName(name);
}

class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editDisplayNameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: AppSettingsStore.maxDisplayNameLength,
        decoration: InputDecoration(
          hintText: l10n.displayNameHint,
          labelText: l10n.displayName,
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
