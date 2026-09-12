import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../shared/navigation/noteon_page_route.dart';
import '../../../shared/widgets/noteon_background.dart';
import '../../../shared/widgets/noteon_empty_state.dart';
import '../../../shared/widgets/noteon_note_tile.dart';
import '../../../shared/widgets/noteon_section_header.dart';
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
    final groupedAsync = ref.watch(groupedNotesProvider);
    final folders = ref.watch(foldersListProvider).valueOrNull ?? const [];
    final tags = ref.watch(tagsListProvider).valueOrNull ?? const [];

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
        titleSpacing: 0,
        title: Text(
          l10n.appName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
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
                  if (totalNotes == 0) {
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

                  return RefreshIndicator(
                    color: AppColors.teal,
                    onRefresh: _refreshAll,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        108,
                      ),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NoteonSectionHeader(
                              title: _bucketLabel(l10n, section.bucket),
                              padding: EdgeInsets.only(
                                top: index == 0 ? 4 : 20,
                                bottom: 10,
                                left: 4,
                                right: 4,
                              ),
                            ),
                            for (var i = 0; i < section.notes.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              NoteonNoteTile(
                                note: section.notes[i],
                                onTap: () => _openNote(section.notes[i]),
                              ),
                            ],
                          ],
                        );
                      },
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
