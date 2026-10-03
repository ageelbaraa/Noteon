import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../features/notes/data/note.dart';
import '../../features/notes/data/note_content_codec.dart';

/// Production-grade note row for the home list.
class NoteonNoteTile extends StatelessWidget {
  const NoteonNoteTile({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
    this.highlightQuery,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectionMode;
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.tealLight : AppColors.tealDark;
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat.yMMMd(locale).add_jm().format(note.updatedAt);

    final title = note.title.trim().isEmpty ? l10n.untitledNote : note.title;
    final preview = note.isLocked
        ? l10n.lockedNotePreview
        : NoteContentCodec.plainTextPreview(note.contentJson);
    final previewText = preview.isEmpty ? l10n.emptyNotePreview : preview;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.25,
      color: selected ? accent : null,
    );

    return Semantics(
      label: title,
      selected: selectionMode ? selected : null,
      button: true,
      onLongPressHint: selectionMode ? null : l10n.enterSelectionMode,
      child: Material(
        color: selected
            ? AppColors.teal.withValues(alpha: isDark ? 0.22 : 0.12)
            : theme.cardTheme.color ?? scheme.surfaceContainerHigh,
        borderRadius: AppRadii.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppRadii.card,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppRadii.card,
              border: Border.all(
                color: selected
                    ? AppColors.teal.withValues(alpha: isDark ? 0.75 : 0.55)
                    : scheme.outlineVariant.withValues(alpha: 0.4),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md + 2,
                AppSpacing.lg,
                AppSpacing.md + 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode) ...[
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: 12,
                        top: 2,
                      ),
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 22,
                        color: selected ? accent : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedTitle(
                          title: title,
                          query: highlightQuery,
                          style: titleStyle,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          previewText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              dateLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (note.isLocked) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withValues(
                                    alpha: isDark ? 0.22 : 0.1,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.sm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 12,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.lockedNotePreview,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact note card for the home grid view.
class NoteonNoteGridCard extends StatelessWidget {
  const NoteonNoteGridCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
    this.highlightQuery,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectionMode;
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.tealLight : AppColors.tealDark;
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat.MMMd(locale).format(note.updatedAt);

    final title = note.title.trim().isEmpty ? l10n.untitledNote : note.title;
    final preview = note.isLocked
        ? l10n.lockedNotePreview
        : NoteContentCodec.plainTextPreview(note.contentJson);
    final previewText = preview.isEmpty ? l10n.emptyNotePreview : preview;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.25,
      color: selected ? accent : null,
    );

    return Semantics(
      label: title,
      selected: selectionMode ? selected : null,
      button: true,
      onLongPressHint: selectionMode ? null : l10n.enterSelectionMode,
      child: Material(
        color: selected
            ? AppColors.teal.withValues(alpha: isDark ? 0.22 : 0.12)
            : theme.cardTheme.color ?? scheme.surfaceContainerHigh,
        borderRadius: AppRadii.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppRadii.card,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppRadii.card,
              border: Border.all(
                color: selected
                    ? AppColors.teal.withValues(alpha: isDark ? 0.75 : 0.55)
                    : scheme.outlineVariant.withValues(alpha: 0.4),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (selectionMode) ...[
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 20,
                          color: selected ? accent : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _HighlightedTitle(
                          title: title,
                          query: highlightQuery,
                          style: titleStyle,
                          maxLines: 2,
                        ),
                      ),
                      if (note.isLocked)
                        Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: accent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      previewText,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightedTitle extends StatelessWidget {
  const _HighlightedTitle({
    required this.title,
    required this.style,
    required this.maxLines,
    this.query,
  });

  final String title;
  final String? query;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final q = query?.trim();
    if (q == null || q.length < 2) {
      return Text(
        title,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final lowerTitle = title.toLowerCase();
    final lowerQuery = q.toLowerCase();
    final index = lowerTitle.indexOf(lowerQuery);
    if (index < 0) {
      return Text(
        title,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final end = index + q.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (index > 0) TextSpan(text: title.substring(0, index)),
          TextSpan(
            text: title.substring(index, end),
            style: style?.copyWith(
              backgroundColor: AppColors.teal.withValues(
                alpha: isDark ? 0.35 : 0.22,
              ),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (end < title.length) TextSpan(text: title.substring(end)),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
