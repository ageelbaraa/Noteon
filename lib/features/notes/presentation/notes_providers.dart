import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../folders/data/folder.dart';
import '../../tags/data/tag.dart';
import '../data/note.dart';
import '../domain/note_date_grouper.dart';
import '../domain/notes_query.dart';

/// How the notes list scopes folders.
enum FolderScope { all, unfiled, folder }

class NotesBrowseFilter {
  const NotesBrowseFilter({
    this.folderScope = FolderScope.all,
    this.folderId,
    this.tagId,
    this.searchQuery = '',
    this.searchVisible = false,
  });

  final FolderScope folderScope;
  final int? folderId;
  final int? tagId;
  final String searchQuery;
  final bool searchVisible;

  bool get hasActiveFilter =>
      folderScope != FolderScope.all ||
      tagId != null ||
      searchQuery.trim().isNotEmpty;

  NotesBrowseFilter copyWith({
    FolderScope? folderScope,
    int? folderId,
    bool clearFolderId = false,
    int? tagId,
    bool clearTagId = false,
    String? searchQuery,
    bool? searchVisible,
  }) {
    return NotesBrowseFilter(
      folderScope: folderScope ?? this.folderScope,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      tagId: clearTagId ? null : (tagId ?? this.tagId),
      searchQuery: searchQuery ?? this.searchQuery,
      searchVisible: searchVisible ?? this.searchVisible,
    );
  }
}

class NotesBrowseFilterNotifier extends Notifier<NotesBrowseFilter> {
  @override
  NotesBrowseFilter build() => const NotesBrowseFilter();

  void setSearchVisible(bool visible) {
    state = state.copyWith(
      searchVisible: visible,
      searchQuery: visible ? state.searchQuery : '',
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void showAllFolders() {
    state = state.copyWith(
      folderScope: FolderScope.all,
      clearFolderId: true,
    );
  }

  void showUnfiled() {
    state = state.copyWith(
      folderScope: FolderScope.unfiled,
      clearFolderId: true,
    );
  }

  void selectFolder(int folderId) {
    state = state.copyWith(
      folderScope: FolderScope.folder,
      folderId: folderId,
    );
  }

  void selectTag(int? tagId) {
    if (tagId == null) {
      state = state.copyWith(clearTagId: true);
    } else {
      state = state.copyWith(tagId: tagId);
    }
  }

  void clearFilters() {
    state = NotesBrowseFilter(searchVisible: state.searchVisible);
  }
}

final notesBrowseFilterProvider =
    NotifierProvider<NotesBrowseFilterNotifier, NotesBrowseFilter>(
      NotesBrowseFilterNotifier.new,
    );

/// Live list of notes ordered by most recently updated.
final notesListProvider =
    AsyncNotifierProvider<NotesListNotifier, List<Note>>(NotesListNotifier.new);

class NotesListNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() {
    return ref.watch(noteRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(noteRepositoryProvider).getAll(),
    );
  }
}

final foldersListProvider =
    AsyncNotifierProvider<FoldersListNotifier, List<Folder>>(
      FoldersListNotifier.new,
    );

class FoldersListNotifier extends AsyncNotifier<List<Folder>> {
  @override
  Future<List<Folder>> build() {
    return ref.watch(folderRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(folderRepositoryProvider).getAll(),
    );
  }
}

final tagsListProvider =
    AsyncNotifierProvider<TagsListNotifier, List<Tag>>(TagsListNotifier.new);

class TagsListNotifier extends AsyncNotifier<List<Tag>> {
  @override
  Future<List<Tag>> build() {
    return ref.watch(tagRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(tagRepositoryProvider).getAll(),
    );
  }
}

/// Notes after folder/tag/search filters, still newest-first.
final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final notesAsync = ref.watch(notesListProvider);
  final foldersAsync = ref.watch(foldersListProvider);
  final tagsAsync = ref.watch(tagsListProvider);
  final filter = ref.watch(notesBrowseFilterProvider);

  if (notesAsync.isLoading || foldersAsync.isLoading || tagsAsync.isLoading) {
    return const AsyncLoading();
  }
  if (notesAsync.hasError) {
    return AsyncError(notesAsync.error!, notesAsync.stackTrace!);
  }
  if (foldersAsync.hasError) {
    return AsyncError(foldersAsync.error!, foldersAsync.stackTrace!);
  }
  if (tagsAsync.hasError) {
    return AsyncError(tagsAsync.error!, tagsAsync.stackTrace!);
  }

  final notes = notesAsync.requireValue;
  final folders = foldersAsync.requireValue;
  final tags = tagsAsync.requireValue;

  final filtered = NotesQuery.apply(
    notes: notes,
    folders: folders,
    tags: tags,
    folderId: filter.folderScope == FolderScope.folder ? filter.folderId : null,
    unfiledOnly: filter.folderScope == FolderScope.unfiled,
    tagId: filter.tagId,
    query: filter.searchQuery,
  );

  return AsyncData(filtered);
});

/// Filtered notes grouped by updated date.
final groupedNotesProvider = Provider<AsyncValue<List<NoteDateSection>>>((ref) {
  final filtered = ref.watch(filteredNotesProvider);
  return filtered.whenData(NoteDateGrouper.group);
});
