import 'package:isar_community/isar.dart';

import '../../../core/media/media_storage_service.dart';
import 'media_ref.dart';
import 'note.dart';
import 'note_media_paths.dart';

/// CRUD access for [Note] records and their folder/tag relationships.
class NoteRepository {
  NoteRepository(this._isar, {MediaStorageService? mediaStorage})
      : _mediaStorage = mediaStorage;

  final Isar _isar;
  final MediaStorageService? _mediaStorage;

  Future<Note?> getById(Id id) => _isar.notes.get(id);

  Future<List<Note>> getAll({bool newestFirst = true}) {
    final query = _isar.notes.where();
    return newestFirst
        ? query.sortByUpdatedAtDesc().findAll()
        : query.sortByUpdatedAt().findAll();
  }

  Future<List<Note>> getByFolderId(int? folderId) {
    if (folderId == null) {
      return _isar.notes
          .filter()
          .folderIdIsNull()
          .sortByUpdatedAtDesc()
          .findAll();
    }
    return _isar.notes
        .filter()
        .folderIdEqualTo(folderId)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  Future<List<Note>> getByTagId(int tagId) {
    return _isar.notes
        .filter()
        .tagIdsElementEqualTo(tagId)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  /// Case-insensitive title contains search.
  Future<List<Note>> searchByTitle(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getAll();
    }
    return _isar.notes
        .filter()
        .titleContains(trimmed, caseSensitive: false)
        .sortByUpdatedAtDesc()
        .findAll();
  }

  Future<Id> create({
    String title = '',
    String contentJson = '',
    int? folderId,
    List<int> tagIds = const [],
    List<MediaRef> mediaRefs = const [],
    bool isLocked = false,
  }) async {
    final now = DateTime.now();
    final note = Note()
      ..title = title
      ..contentJson = contentJson
      ..folderId = folderId
      ..tagIds = List<int>.from(tagIds)
      ..mediaRefs = List<MediaRef>.from(mediaRefs)
      ..isLocked = isLocked
      ..createdAt = now
      ..updatedAt = now;

    return _isar.writeTxn(() => _isar.notes.put(note));
  }

  Future<void> update(Note note, {bool touchTimestamp = true}) async {
    if (touchTimestamp) {
      note.updatedAt = DateTime.now();
    }
    await _isar.writeTxn(() => _isar.notes.put(note));
  }

  Future<void> setFolder(Note note, int? folderId) async {
    note.folderId = folderId;
    await update(note);
  }

  Future<void> setTagIds(Note note, List<int> tagIds) async {
    note.tagIds = List<int>.from(tagIds);
    await update(note);
  }

  /// Deletes the note and removes associated local media files.
  Future<bool> delete(Id id) async {
    final note = await getById(id);
    if (note == null) {
      return false;
    }

    final media = _mediaStorage;
    if (media != null) {
      final paths = <String>{
        ...note.mediaRefs.map((ref) => ref.relativePath),
        ...NoteMediaPaths.extractFromContentJson(note.contentJson),
      };
      for (final path in paths) {
        await media.deleteRelativePath(path);
      }
      // Encrypted media lives under locked/{noteId}/ and is not in mediaRefs.
      await media.deleteNoteLockedMedia(id);
    }

    return _isar.writeTxn(() => _isar.notes.delete(id));
  }
}
