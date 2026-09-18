import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../shared/navigation/noteon_page_route.dart';
import '../../../shared/widgets/noteon_background.dart';
import '../../../shared/widgets/noteon_empty_state.dart';
import '../../../shared/widgets/noteon_group_surface.dart';
import '../../../shared/widgets/noteon_note_tile.dart';
import '../../../shared/widgets/noteon_section_header.dart';
import '../../folders/data/folder.dart';
import '../data/note.dart';
import '../domain/note_date_grouper.dart';
import 'note_editor_screen.dart';
import 'notes_organize_drawer.dart';
import 'notes_providers.dart';

/// Home notes list with search, filters, and date grouping.
class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(notesListProvider.notifier).refresh(),
      ref.read(foldersListProvider.notifier).refresh(),
      ref.read(tagsListProvider.notifier).refresh(),
    ]);
  }

  Future<void> _openNewNote() async {
    final filter = ref.read(notesBrowseFilterProvider);
    final initialFolderId =
        filter.folderScope == FolderScope.folder ? filter.folderId : null;
    final created = await Navigator.of(context).push<bool>(
      NoteonPageRoute(
        builder: (_) => NoteEditorScreen(initialFolderId: initialFolderId),
      ),
    );
    if (created == true) {
      await _refreshAll();
    }
  }

  Future<void> _openNote(Note note) async {
    final changed = await Navigator.of(context).push<bool>(
      NoteonPageRoute(builder: (_) => NoteEditorScreen(noteId: note.id)),
    );
    if (changed == true) {
      await _refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filter = ref.watch(notesBrowseFilterProvider);
    final viewMode = ref.watch(notesViewModeProvider);
    final groupedAsync = ref.watch(groupedNotesProvider);
    final folders = ref.watch(foldersListProvider).valueOrNull ?? const [];
    final tags = ref.watch(tagsListProvider).valueOrNull ?? const [];
    final roots =
        folders.where((folder) => folder.parentFolderId == null).toList();

    if (!filter.searchVisible && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    String? folderFilterLabel;
    if (filter.folderScope == FolderScope.unfiled) {
      folderFilterLabel = l10n.unfiledNotes;
    } else if (filter.folderScope == FolderScope.folder &&
        filter.folderId != null) {
      final match = folders.where((f) => f.id == filter.folderId);
      if (match.isNotEmpty) {
        folderFilterLabel = l10n.filterByFolder(match.first.name);
      }
    }

    String? tagFilterLabel;
    if (filter.tagId != null) {
      final match = tags.where((t) => t.id == filter.tagId);
      if (match.isNotEmpty) {
        tagFilterLabel = l10n.filterByTag(match.first.name);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const NotesOrganizeDrawer(),
      appBar: AppBar(
        title: Text(
          l10n.appName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: viewMode == NotesViewMode.list
                ? l10n.notesViewGrid
                : l10n.notesViewList,
            onPressed: () =>
                ref.read(notesViewModeProvider.notifier).toggle(),
            icon: Icon(
              viewMode == NotesViewMode.list
                  ? Icons.grid_view_rounded
                  : Icons.view_agenda_rounded,
            ),
          ),
          IconButton(
            tooltip: l10n.searchNotes,
            onPressed: () {
              final next = !filter.searchVisible;
              ref
                  .read(notesBrowseFilterProvider.notifier)
                  .setSearchVisible(next);
              if (next) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocus.requestFocus();
                });
              } else {
                _searchController.clear();
                _searchFocus.unfocus();
              }
            },
            icon: Icon(
              filter.searchVisible ? Icons.close_rounded : Icons.search_rounded,
            ),
          ),
        ],
      ),
      body: NoteonBackground(
        child: Column(
          children: [
            _FolderChipStrip(
              folders: roots,
              allFolders: folders,
              selectedScope: filter.folderScope,
              selectedFolderId: filter.folderId,
              onAll: () =>
                  ref.read(notesBrowseFilterProvider.notifier).clearFilters(),
              onUnfiled: () =>
                  ref.read(notesBrowseFilterProvider.notifier).showUnfiled(),
              onFolder: (id) => ref
                  .read(notesBrowseFilterProvider.notifier)
                  .selectFolder(id),
            ),
            AnimatedSize(
              duration: AppMotion.normal,
              curve: AppMotion.standard,
              alignment: Alignment.topCenter,
              child: filter.searchVisible
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: l10n.searchNotes,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: filter.searchQuery.trim().isEmpty
                              ? null
                              : IconButton(
                                  tooltip: l10n.clearFilters,
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                          notesBrowseFilterProvider.notifier,
                                        )
                                        .setSearchQuery('');
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                        ),
                        onChanged: (value) {
                          ref
                              .read(notesBrowseFilterProvider.notifier)
                              .setSearchQuery(value);
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: filter.hasActiveFilter
                  ? _ActiveFiltersBar(
                      key: const ValueKey('filters'),
                      folderLabel: folderFilterLabel,
                      tagLabel: tagFilterLabel,
                      searchQuery: filter.searchQuery.trim().isEmpty
                          ? null
                          : filter.searchQuery.trim(),
                      onClear: () {
                        ref
                            .read(notesBrowseFilterProvider.notifier)
                            .clearFilters();
                        _searchController.clear();
                      },
                    )
                  : const SizedBox.shrink(key: ValueKey('no-filters')),
            ),
            Expanded(
              child: groupedAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => NoteonLoadError(
                  message: l10n.notesLoadError,
                  retryLabel: l10n.retry,
                  onRetry: _refreshAll,
                ),
                data: (sections) {
                  final totalNotes =
                      sections.fold<int>(0, (sum, s) => sum + s.notes.length);
                  final childFolders =
                      filter.folderScope == FolderScope.folder &&
                              filter.folderId != null
                          ? folders
                              .where((f) => f.parentFolderId == filter.folderId)
                              .toList(growable: false)
                          : const <Folder>[];

                  if (totalNotes == 0 && childFolders.isEmpty) {
                    if (filter.hasActiveFilter) {
                      return _FilteredEmptyState(
                        onClear: () {
                          ref
                              .read(notesBrowseFilterProvider.notifier)
                              .clearFilters();
                          _searchController.clear();
                        },
                      );
                    }
                    return const _EmptyNotesState();
                  }

                  final subfoldersHeader = childFolders.isEmpty
                      ? null
                      : _SubfoldersSection(
                          folders: childFolders,
                          onOpen: (id) => ref
                              .read(notesBrowseFilterProvider.notifier)
                              .selectFolder(id),
                        );

                  return RefreshIndicator(
                    color: AppColors.teal,
                    onRefresh: _refreshAll,
                    child: viewMode == NotesViewMode.grid
                        ? _NotesGridBody(
                            sections: sections,
                            bucketLabel: (bucket) =>
                                _bucketLabel(l10n, bucket),
                            onOpen: _openNote,
                            leading: subfoldersHeader,
                            emptyNotesPlaceholder: totalNotes == 0
                                ? NoteonEmptyState(
                                    icon: Icons.note_alt_outlined,
                                    title: l10n.emptyNotesTitle,
                                    subtitle: l10n.emptyNotesSubtitle,
                                  )
                                : null,
                          )
                        : _NotesListBody(
                            sections: sections,
                            bucketLabel: (bucket) =>
                                _bucketLabel(l10n, bucket),
                            onOpen: _openNote,
                            leading: subfoldersHeader,
                            emptyNotesPlaceholder: totalNotes == 0
                                ? NoteonEmptyState(
                                    icon: Icons.note_alt_outlined,
                                    title: l10n.emptyNotesTitle,
                                    subtitle: l10n.emptyNotesSubtitle,
                                  )
                                : null,
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewNote,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.newNote),
      ),
    );
  }

  String _bucketLabel(AppLocalizations l10n, NoteDateBucket bucket) {
    return switch (bucket) {
      NoteDateBucket.today => l10n.dateGroupToday,
      NoteDateBucket.yesterday => l10n.dateGroupYesterday,
      NoteDateBucket.thisWeek => l10n.dateGroupThisWeek,
      NoteDateBucket.older => l10n.dateGroupOlder,
    };
  }
}

class _FolderChipStrip extends StatelessWidget {
  const _FolderChipStrip({
    required this.folders,
    required this.allFolders,
    required this.selectedScope,
    required this.selectedFolderId,
    required this.onAll,
    required this.onUnfiled,
    required this.onFolder,
  });

  final List<Folder> folders;
  final List<Folder> allFolders;
  final FolderScope selectedScope;
  final int? selectedFolderId;
  final VoidCallback onAll;
  final VoidCallback onUnfiled;
  final ValueChanged<int> onFolder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = allFolders
        .where((f) => f.parentFolderId != null)
        .toList(growable: false);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          4,
          AppSpacing.lg,
          8,
        ),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilterChip(
              avatar: const Icon(Icons.notes_rounded, size: 16),
              label: Text(l10n.allNotes),
              selected: selectedScope == FolderScope.all,
              onSelected: (_) => onAll(),
              visualDensity: VisualDensity.compact,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilterChip(
              avatar: const Icon(Icons.inbox_outlined, size: 16),
              label: Text(l10n.unfiledNotes),
              selected: selectedScope == FolderScope.unfiled,
              onSelected: (_) => onUnfiled(),
              visualDensity: VisualDensity.compact,
            ),
          ),
          for (final folder in folders) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(
                avatar: const Icon(Icons.folder_outlined, size: 16),
                label: Text(folder.name),
                selected: selectedScope == FolderScope.folder &&
                    selectedFolderId == folder.id,
                onSelected: (_) => onFolder(folder.id),
                visualDensity: VisualDensity.compact,
              ),
            ),
            for (final child in children.where(
              (c) => c.parentFolderId == folder.id,
            ))
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: FilterChip(
                  avatar: const Icon(Icons.subdirectory_arrow_right, size: 16),
                  label: Text(child.name),
                  selected: selectedScope == FolderScope.folder &&
                      selectedFolderId == child.id,
                  onSelected: (_) => onFolder(child.id),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SubfoldersSection extends StatelessWidget {
  const _SubfoldersSection({
    required this.folders,
    required this.onOpen,
  });

  final List<Folder> folders;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoteonSectionHeader(
          title: l10n.subfolders,
          padding: const EdgeInsets.only(top: 4, bottom: 10, left: 4, right: 4),
        ),
        NoteonGroupSurface(
          children: [
            for (final folder in folders)
              NoteonGroupTile(
                leading: const Icon(Icons.folder_outlined),
                title: folder.name,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onOpen(folder.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _NotesListBody extends StatelessWidget {
  const _NotesListBody({
    required this.sections,
    required this.bucketLabel,
    required this.onOpen,
    this.leading,
    this.emptyNotesPlaceholder,
  });

  final List<NoteDateSection> sections;
  final String Function(NoteDateBucket bucket) bucketLabel;
  final ValueChanged<Note> onOpen;
  final Widget? leading;
  final Widget? emptyNotesPlaceholder;

  @override
  Widget build(BuildContext context) {
    final hasNotes = sections.any((s) => s.notes.isNotEmpty);
    final showEmpty = !hasNotes && emptyNotesPlaceholder != null;
    final topCount = (leading != null ? 1 : 0) + (showEmpty ? 1 : 0);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        108,
      ),
      itemCount: topCount + (hasNotes ? sections.length : 0),
      itemBuilder: (context, index) {
        var cursor = index;
        if (leading != null) {
          if (cursor == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: leading,
            );
          }
          cursor -= 1;
        }
        if (showEmpty) {
          if (cursor == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: emptyNotesPlaceholder,
            );
          }
          cursor -= 1;
        }
        final section = sections[cursor];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NoteonSectionHeader(
              title: bucketLabel(section.bucket),
              padding: EdgeInsets.only(
                top: cursor == 0 && leading == null ? 4 : 20,
                bottom: 10,
                left: 4,
                right: 4,
              ),
            ),
            for (var i = 0; i < section.notes.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              NoteonNoteTile(
                note: section.notes[i],
                onTap: () => onOpen(section.notes[i]),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _NotesGridBody extends StatelessWidget {
  const _NotesGridBody({
    required this.sections,
    required this.bucketLabel,
    required this.onOpen,
    this.leading,
    this.emptyNotesPlaceholder,
  });

  final List<NoteDateSection> sections;
  final String Function(NoteDateBucket bucket) bucketLabel;
  final ValueChanged<Note> onOpen;
  final Widget? leading;
  final Widget? emptyNotesPlaceholder;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 720 ? 3 : 2;
    final hasNotes = sections.any((s) => s.notes.isNotEmpty);
    final showEmpty = !hasNotes && emptyNotesPlaceholder != null;
    final topCount = (leading != null ? 1 : 0) + (showEmpty ? 1 : 0);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        108,
      ),
      itemCount: topCount + (hasNotes ? sections.length : 0),
      itemBuilder: (context, index) {
        var cursor = index;
        if (leading != null) {
          if (cursor == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: leading,
            );
          }
          cursor -= 1;
        }
        if (showEmpty) {
          if (cursor == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: emptyNotesPlaceholder,
            );
          }
          cursor -= 1;
        }
        final section = sections[cursor];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NoteonSectionHeader(
              title: bucketLabel(section.bucket),
              padding: EdgeInsets.only(
                top: cursor == 0 && leading == null ? 4 : 20,
                bottom: 10,
                left: 4,
                right: 4,
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: section.notes.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, i) {
                final note = section.notes[i];
                return NoteonNoteGridCard(
                  note: note,
                  onTap: () => onOpen(note),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ActiveFiltersBar extends StatelessWidget {
  const _ActiveFiltersBar({
    super.key,
    required this.folderLabel,
    required this.tagLabel,
    required this.searchQuery,
    required this.onClear,
  });

  final String? folderLabel;
  final String? tagLabel;
  final String? searchQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = searchQuery;
    final queryLabel = query == null
        ? null
        : l10n.searchFilterLabel(
            query.length > 24 ? '${query.substring(0, 24)}…' : query,
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (folderLabel != null)
              Chip(
                avatar: const Icon(Icons.folder_outlined, size: 16),
                label: Text(folderLabel!),
                visualDensity: VisualDensity.compact,
              ),
            if (tagLabel != null)
              Chip(
                avatar: const Icon(Icons.label_outline, size: 16),
                label: Text(tagLabel!),
                visualDensity: VisualDensity.compact,
              ),
            if (queryLabel != null)
              Chip(
                avatar: const Icon(Icons.search, size: 16),
                label: Text(queryLabel),
                visualDensity: VisualDensity.compact,
              ),
            ActionChip(
              label: Text(l10n.clearFilters),
              onPressed: onClear,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NoteonEmptyState(
      icon: Icons.search_off_rounded,
      title: l10n.noMatchingNotes,
      subtitle: l10n.noMatchingNotesSubtitle,
      action: TextButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: Text(l10n.clearFilters),
      ),
    );
  }
}

class _EmptyNotesState extends StatelessWidget {
  const _EmptyNotesState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NoteonEmptyState(
      useBrandMark: true,
      title: l10n.emptyNotesTitle,
      subtitle: '${l10n.appTagline}\n\n${l10n.emptyNotesSubtitle}',
    );
  }
}
