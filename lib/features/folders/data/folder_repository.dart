import 'package:isar_community/isar.dart';

import '../../notes/data/note.dart';
import '../data/folder.dart';

/// CRUD access for [Folder] records, including subfolder lookups.
class FolderRepository {
  FolderRepository(this._isar);

  final Isar _isar;

  Future<Folder?> getById(Id id) => _isar.folders.get(id);

  Future<List<Folder>> getAll() {
    return _isar.folders.where().sortByName().findAll();
  }

  /// Root folders when [parentId] is null; otherwise direct children.
  Future<List<Folder>> getChildren({int? parentId}) {
    if (parentId == null) {
      return _isar.folders
          .filter()
          .parentFolderIdIsNull()
          .sortByName()
          .findAll();
    }
    return _isar.folders
        .filter()
        .parentFolderIdEqualTo(parentId)
        .sortByName()
        .findAll();
  }

  Future<Id> create({
    required String name,
    int? parentFolderId,
  }) async {
    final now = DateTime.now();
    final folder = Folder()
      ..name = name.trim()
      ..parentFolderId = parentFolderId
      ..createdAt = now
      ..updatedAt = now;

    return _isar.writeTxn(() => _isar.folders.put(folder));
  }

  Future<void> rename(Folder folder, String newName) async {
    folder
      ..name = newName.trim()
      ..updatedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.folders.put(folder));
  }

  Future<void> update(Folder folder) async {
    folder.updatedAt = DateTime.now();
    await _isar.writeTxn(() => _isar.folders.put(folder));
  }

  /// Deletes [id] and its subfolder tree.
  ///
  /// Notes in deleted folders are unfiled (`folderId = null`) and are never
  /// deleted by this operation.
  Future<void> deleteSafely(Id id) async {
    final subtreeIds = await _collectSubtreeIds(id);
    await _isar.writeTxn(() async {
      for (final folderId in subtreeIds) {
        final notesInFolder = await _isar.notes
            .filter()
            .folderIdEqualTo(folderId)
            .findAll();
        for (final note in notesInFolder) {
          note.folderId = null;
          await _isar.notes.put(note);
        }
        await _isar.folders.delete(folderId);
      }
    });
  }

  /// Depth-first collection ending with [rootId] last so children delete first.
  Future<List<Id>> _collectSubtreeIds(Id rootId) async {
    final result = <Id>[];

    Future<void> walk(Id id) async {
      final children = await _isar.folders
          .filter()
          .parentFolderIdEqualTo(id)
          .findAll();
      for (final child in children) {
        await walk(child.id);
      }
      result.add(id);
    }

    await walk(rootId);
    return result;
  }
}
