import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../shared/navigation/noteon_page_route.dart';
import '../../../shared/widgets/noteon_logo.dart';
import '../../../shared/widgets/noteon_section_header.dart';
import '../../folders/data/folder.dart';
import '../../folders/presentation/folders_screen.dart';
import '../../tags/presentation/tags_screen.dart';
import 'notes_providers.dart';

/// Side panel for selecting folder/tag filters and opening managers.
class NotesOrganizeDrawer extends ConsumerWidget {
  const NotesOrganizeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filter = ref.watch(notesBrowseFilterProvider);
    final folders = ref.watch(foldersListProvider).valueOrNull ?? const [];
    final tags = ref.watch(tagsListProvider).valueOrNull ?? const [];
    final roots =
        folders.where((folder) => folder.parentFolderId == null).toList();
    final allSelected =
        filter.folderScope == FolderScope.all && filter.tagId == null;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const NoteonLogo(
                    size: 36,
                    variant: NoteonLogoVariant.branded,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.organize,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          l10n.appTagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        _DrawerNavTile(
                          icon: Icons.notes_rounded,
                          label: l10n.allNotes,
                          selected: allSelected,
                          onTap: () {
                            ref
                                .read(notesBrowseFilterProvider.notifier)
                                .clearFilters();
                            Navigator.pop(context);
                          },
                        ),
                        _DrawerNavTile(
                          icon: Icons.inbox_outlined,
                          label: l10n.unfiledNotes,
                          selected:
                              filter.folderScope == FolderScope.unfiled,
                          onTap: () {
                            ref
                                .read(notesBrowseFilterProvider.notifier)
                                .showUnfiled();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  NoteonSectionHeader(
                    title: l10n.folders,
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          NoteonPageRoute(
                            builder: (_) => const FoldersScreen(),
                          ),
                        );
                      },
                      child: Text(l10n.manageFolders),
                    ),
                  ),
                  if (roots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Text(
                        l10n.emptyFolders,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          for (final root in roots)
                            ..._folderEntries(
                              context,
                              ref,
                              folders: folders,
                              folder: root,
                              depth: 0,
                              selectedFolderId:
                                  filter.folderScope == FolderScope.folder
                                      ? filter.folderId
                                      : null,
                            ),
                        ],
                      ),
                    ),
                  NoteonSectionHeader(
                    title: l10n.tags,
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          NoteonPageRoute(
                            builder: (_) => const TagsScreen(),
                          ),
                        );
                      },
                      child: Text(l10n.manageTags),
                    ),
                  ),
                  if (tags.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Text(
                        l10n.emptyTags,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          for (final tag in tags)
                            _DrawerNavTile(
                              icon: Icons.label_outline_rounded,
                              label: tag.name,
                              selected: filter.tagId == tag.id,
                              onTap: () {
                                ref
                                    .read(notesBrowseFilterProvider.notifier)
                                    .selectTag(tag.id);
                                Navigator.pop(context);
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _folderEntries(
    BuildContext context,
    WidgetRef ref, {
    required List<Folder> folders,
    required Folder folder,
    required int depth,
    required int? selectedFolderId,
  }) {
    final children =
        folders.where((item) => item.parentFolderId == folder.id).toList();
    return [
      _DrawerNavTile(
        icon: depth == 0
            ? Icons.folder_outlined
            : Icons.folder_open_outlined,
        label: folder.name,
        selected: selectedFolderId == folder.id,
        indent: depth,
        onTap: () {
          ref.read(notesBrowseFilterProvider.notifier).selectFolder(folder.id);
          Navigator.pop(context);
        },
      ),
      for (final child in children)
        ..._folderEntries(
          context,
          ref,
          folders: folders,
          folder: child,
          depth: depth + 1,
          selectedFolderId: selectedFolderId,
        ),
    ];
  }
}

class _DrawerNavTile extends StatelessWidget {
  const _DrawerNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.indent = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int indent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.tealLight : AppColors.tealDark;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: indent * 14.0,
        bottom: 2,
      ),
      child: Material(
        color: selected
            ? AppColors.teal.withValues(alpha: isDark ? 0.2 : 0.12)
            : Colors.transparent,
        borderRadius: AppRadii.control,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.control,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? accent : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
