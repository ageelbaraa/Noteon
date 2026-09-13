import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/database_providers.dart';
import '../../../shared/widgets/noteon_background.dart';
import '../../../shared/widgets/noteon_empty_state.dart';
import '../../../shared/widgets/noteon_group_surface.dart';
import '../../notes/presentation/notes_providers.dart';
import '../data/folder.dart';

/// Full-screen folder manager with create / rename / delete and subfolders.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final foldersAsync = ref.watch(foldersListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.manageFolders,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.newFolder,
            onPressed: () => _createFolder(context, ref),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      body: NoteonBackground(
        child: foldersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => NoteonLoadError(
            message: l10n.foldersLoadError,
            retryLabel: l10n.retry,
            onRetry: () => ref.read(foldersListProvider.notifier).refresh(),
          ),
          data: (folders) {
            if (folders.isEmpty) {
              return NoteonEmptyState(
                icon: Icons.folder_outlined,
                title: l10n.emptyFolders,
                subtitle: l10n.emptyFoldersSubtitle,
                action: FilledButton.icon(
                  onPressed: () => _createFolder(context, ref),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(l10n.newFolder),
                ),
              );
            }
            final roots = folders
                .where((folder) => folder.parentFolderId == null)
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                NoteonGroupSurface(
                  children: [
                    for (final root in roots)
                      ..._flattenFolder(
                        context,
                        ref,
                        folder: root,
                        folders: folders,
                        depth: 0,
                        onRefresh: () async {
                          await ref
                              .read(foldersListProvider.notifier)
                              .refresh();
                          await ref.read(notesListProvider.notifier).refresh();
                        },
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

  List<Widget> _flattenFolder(
    BuildContext context,
    WidgetRef ref, {
    required Folder folder,
    required List<Folder> folders,
    required int depth,
    required Future<void> Function() onRefresh,
  }) {
    final children =
        folders.where((f) => f.parentFolderId == folder.id).toList();
    return [
      _FolderRow(
        folder: folder,
        depth: depth,
        onRefresh: onRefresh,
      ),
      for (final child in children)
        ..._flattenFolder(
          context,
          ref,
          folder: child,
          folders: folders,
          depth: depth + 1,
          onRefresh: onRefresh,
        ),
    ];
  }

  Future<void> _createFolder(
    BuildContext context,
    WidgetRef ref, {
    int? parentId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptName(
      context,
      title: parentId == null ? l10n.newFolder : l10n.newSubfolder,
      hint: l10n.folderNameHint,
      confirmLabel: l10n.create,
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    try {
      await ref.read(folderRepositoryProvider).create(
            name: name,
            parentFolderId: parentId,
          );
      await ref.read(foldersListProvider.notifier).refresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.folderActionFailed)),
        );
      }
    }
  }
}

class _FolderRow extends ConsumerWidget {
  const _FolderRow({
    required this.folder,
    required this.depth,
    required this.onRefresh,
  });

  final Folder folder;
  final int depth;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return NoteonGroupTile(
      indent: depth,
      leading: Icon(
        depth == 0 ? Icons.folder_rounded : Icons.folder_open_outlined,
      ),
      title: folder.name,
      onTap: null,
      trailing: PopupMenuButton<String>(
        tooltip: l10n.organize,
        onSelected: (value) async {
          try {
            if (value == 'sub') {
              final name = await _promptName(
                context,
                title: l10n.newSubfolder,
                hint: l10n.folderNameHint,
                confirmLabel: l10n.create,
              );
              if (name == null || name.trim().isEmpty) {
                return;
              }
              await ref.read(folderRepositoryProvider).create(
                    name: name,
                    parentFolderId: folder.id,
                  );
              await onRefresh();
              return;
            }
            if (value == 'rename') {
              final name = await _promptName(
                context,
                title: l10n.renameFolder,
                hint: l10n.folderNameHint,
                confirmLabel: l10n.rename,
                initial: folder.name,
              );
              if (name == null || name.trim().isEmpty) {
                return;
              }
              await ref.read(folderRepositoryProvider).rename(folder, name);
              await onRefresh();
              return;
            }
            if (value == 'delete') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.deleteFolderTitle),
                  content: Text(l10n.deleteFolderMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(folderRepositoryProvider).deleteSafely(folder.id);
                await onRefresh();
              }
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.folderActionFailed)),
              );
            }
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'sub', child: Text(l10n.newSubfolder)),
          PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
        ],
        child: Icon(
          Icons.more_vert_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

Future<String?> _promptName(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: InputDecoration(hintText: hint, counterText: ''),
          textCapitalization: TextCapitalization.sentences,
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
