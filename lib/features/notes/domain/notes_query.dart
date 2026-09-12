import '../../folders/data/folder.dart';
import '../../tags/data/tag.dart';
import '../data/note.dart';
import '../data/note_content_codec.dart';

/// Local filter + search over notes (no cloud / API).
abstract final class NotesQuery {
  /// Filters by folder/tag and matches [query] against title, body, tags,
  /// and folder name. Locked note bodies are excluded from content matching.
  static List<Note> apply({
    required List<Note> notes,
    required List<Folder> folders,
    required List<Tag> tags,
    int? folderId,
    bool unfiledOnly = false,
    int? tagId,
    String query = '',
  }) {
    final folderById = {for (final folder in folders) folder.id: folder};
    final tagById = {for (final tag in tags) tag.id: tag};
    final needle = query.trim().toLowerCase();

    return notes.where((note) {
      if (unfiledOnly && note.folderId != null) {
        return false;
      }
      if (folderId != null && note.folderId != folderId) {
        return false;
      }
      if (tagId != null && !note.tagIds.contains(tagId)) {
        return false;
      }
      if (needle.isEmpty) {
        return true;
      }
      return _matchesQuery(
        note: note,
        needle: needle,
        folderById: folderById,
        tagById: tagById,
      );
    }).toList(growable: false);
  }

  static bool _matchesQuery({
    required Note note,
    required String needle,
    required Map<int, Folder> folderById,
    required Map<int, Tag> tagById,
  }) {
    if (note.title.toLowerCase().contains(needle)) {
      return true;
    }

    if (!note.isLocked) {
      final body = NoteContentCodec.plainTextPreview(
        note.contentJson,
        maxLength: 100000,
      ).toLowerCase();
      if (body.contains(needle)) {
        return true;
      }
    }

    for (final tagId in note.tagIds) {
      final tag = tagById[tagId];
      if (tag != null && tag.name.toLowerCase().contains(needle)) {
        return true;
      }
    }

    if (note.folderId != null) {
      final folder = folderById[note.folderId!];
      if (folder != null && folder.name.toLowerCase().contains(needle)) {
        return true;
      }
    }

    return false;
  }
}
