import 'package:isar_community/isar.dart';

import '../../notes/data/note.dart';
import '../data/tag.dart';

/// CRUD access for [Tag] records.
class TagRepository {
  TagRepository(this._isar);

  final Isar _isar;

  Future<Tag?> getById(Id id) => _isar.tags.get(id);

  Future<Tag?> findByName(String name) {
    return _isar.tags
        .filter()
        .nameEqualTo(name.trim(), caseSensitive: false)
        .findFirst();
  }

  Future<List<Tag>> getAll() {
    return _isar.tags.where().sortByName().findAll();
  }

  /// Creates a tag, or returns the existing id when the name already exists.
  Future<Id> createOrGet(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tag name cannot be empty');
    }

    final existing = await findByName(trimmed);
    if (existing != null) {
      return existing.id;
    }

    final tag = Tag()
      ..name = trimmed
      ..createdAt = DateTime.now();

    return _isar.writeTxn(() => _isar.tags.put(tag));
  }

  Future<void> rename(Tag tag, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tag name cannot be empty');
    }

    final conflict = await findByName(trimmed);
    if (conflict != null && conflict.id != tag.id) {
      throw StateError('A tag with this name already exists');
    }

    tag.name = trimmed;
    await _isar.writeTxn(() => _isar.tags.put(tag));
  }

  /// Deletes the tag and removes it from every note that referenced it.
  Future<void> deleteSafely(Id id) async {
    await _isar.writeTxn(() async {
      final notes = await _isar.notes
          .filter()
          .tagIdsElementEqualTo(id)
          .findAll();
      for (final note in notes) {
        note.tagIds = note.tagIds.where((tagId) => tagId != id).toList();
        await _isar.notes.put(note);
      }
      await _isar.tags.delete(id);
    });
  }

  Future<bool> delete(Id id) => deleteSafely(id).then((_) => true);
}
