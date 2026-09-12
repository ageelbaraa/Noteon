import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/database_providers.dart';
import '../../../shared/widgets/noteon_background.dart';
import '../../../shared/widgets/noteon_empty_state.dart';
import '../../../shared/widgets/noteon_group_surface.dart';
import '../../notes/presentation/notes_providers.dart';

/// Full-screen tag manager with create / rename / delete.
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(tagsListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.manageTags,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.newTag,
            onPressed: () => _createTag(context, ref),
            icon: const Icon(Icons.new_label_outlined),
          ),
        ],
      ),
      body: NoteonBackground(
        child: tagsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => NoteonLoadError(
            message: l10n.tagsLoadError,
            retryLabel: l10n.retry,
            onRetry: () => ref.read(tagsListProvider.notifier).refresh(),
          ),
          data: (tags) {
            if (tags.isEmpty) {
              return NoteonEmptyState(
                icon: Icons.label_outline_rounded,
                title: l10n.emptyTags,
                subtitle: l10n.emptyTagsSubtitle,
                action: FilledButton.icon(
                  onPressed: () => _createTag(context, ref),
                  icon: const Icon(Icons.new_label_outlined),
                  label: Text(l10n.newTag),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                NoteonGroupSurface(
                  children: [
                    for (final tag in tags)
                      NoteonGroupTile(
                        leading: const Icon(Icons.label_rounded),
                        title: tag.name,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'rename') {
                              final name = await _promptTagName(
                                context,
                                title: l10n.renameTag,
                                initial: tag.name,
                                confirmLabel: l10n.rename,
                              );
                              if (name == null || name.trim().isEmpty) {
                                return;
                              }
                              try {
                                await ref
                                    .read(tagRepositoryProvider)
                                    .rename(tag, name);
                                await ref
                                    .read(tagsListProvider.notifier)
                                    .refresh();
                              } catch (error) {
                                if (context.mounted) {
                                  final message = error is StateError
                                      ? l10n.tagAlreadyExists
                                      : l10n.tagActionFailed;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }
                              }
                            } else if (value == 'delete') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(l10n.deleteTagTitle),
                                  content: Text(l10n.deleteTagMessage),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(l10n.delete),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                try {
                                  await ref
                                      .read(tagRepositoryProvider)
                                      .deleteSafely(tag.id);
                                  await ref
                                      .read(tagsListProvider.notifier)
                                      .refresh();
                                  await ref
                                      .read(notesListProvider.notifier)
                                      .refresh();
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.tagActionFailed),
                                      ),
                                    );
                                  }
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(l10n.rename),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(l10n.delete),
                            ),
                          ],
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptTagName(
      context,
      title: l10n.newTag,
      confirmLabel: l10n.create,
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    try {
      await ref.read(tagRepositoryProvider).createOrGet(name);
      await ref.read(tagsListProvider.notifier).refresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tagActionFailed)),
        );
      }
    }
  }
}

Future<String?> _promptTagName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            hintText: l10n.tagNameHint,
            counterText: '',
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}
