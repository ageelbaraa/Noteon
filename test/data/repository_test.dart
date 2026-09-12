import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/database/isar_database.dart';
import 'package:noteon/features/folders/data/folder_repository.dart';
import 'package:noteon/features/notes/data/media_ref.dart';
import 'package:noteon/features/notes/data/note_content_codec.dart';
import 'package:noteon/features/notes/data/note_repository.dart';
import 'package:noteon/features/tags/data/tag_repository.dart';

import '../support/isar_test_helper.dart';

void main() {
  late Directory tempDir;
  late NoteRepository notes;
  late FolderRepository folders;
  late TagRepository tags;

  setUpAll(() async {
    await initializeIsarForTests();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('noteon_isar_');
    final name = 'noteon_test_${DateTime.now().microsecondsSinceEpoch}';
    final isar = await IsarDatabase.openInDirectory(
      tempDir.path,
      name: name,
    );
    notes = NoteRepository(isar);
    folders = FolderRepository(isar);
    tags = TagRepository(isar);
  });

  tearDown(() async {
    await IsarDatabase.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FolderRepository', () {
    test('creates root and subfolders', () async {
      final rootId = await folders.create(name: 'Work');
      final childId = await folders.create(
        name: 'Meetings',
        parentFolderId: rootId,
      );

      final roots = await folders.getChildren();
      final children = await folders.getChildren(parentId: rootId);

      expect(roots.map((f) => f.id), contains(rootId));
      expect(children, hasLength(1));
      expect(children.first.id, childId);
      expect(children.first.parentFolderId, rootId);
    });

    test('updates and deletes folders', () async {
      final id = await folders.create(name: 'Old');
      final folder = await folders.getById(id);
      expect(folder, isNotNull);

      await folders.rename(folder!, 'New');

      expect((await folders.getById(id))!.name, 'New');
      await folders.deleteSafely(id);
      expect(await folders.getById(id), isNull);
    });

    test('deleteSafely unfiles notes and removes subfolders', () async {
      final rootId = await folders.create(name: 'Root');
      final childId = await folders.create(
        name: 'Child',
        parentFolderId: rootId,
      );
      final noteId = await notes.create(title: 'In child', folderId: childId);

      await folders.deleteSafely(rootId);

      expect(await folders.getById(rootId), isNull);
      expect(await folders.getById(childId), isNull);
      final note = await notes.getById(noteId);
      expect(note, isNotNull);
      expect(note!.folderId, isNull);
    });
  });

  group('TagRepository', () {
    test('creates tags and reuses existing names case-insensitively', () async {
      final first = await tags.createOrGet('Ideas');
      final second = await tags.createOrGet('ideas');

      expect(first, second);
      expect(await tags.getAll(), hasLength(1));
    });

    test('renames and deletes tags', () async {
      final id = await tags.createOrGet('Draft');
      final tag = await tags.getById(id);
      await tags.rename(tag!, 'Ready');

      expect((await tags.getById(id))!.name, 'Ready');
      await tags.deleteSafely(id);
      expect(await tags.getById(id), isNull);
    });

    test('deleteSafely strips tag ids from notes', () async {
      final tagId = await tags.createOrGet('temp');
      final noteId = await notes.create(title: 'Tagged', tagIds: [tagId]);
      await tags.deleteSafely(tagId);

      expect(await tags.getById(tagId), isNull);
      expect((await notes.getById(noteId))!.tagIds, isEmpty);
    });
  });

  group('NoteRepository', () {
    test('creates, updates, and deletes notes with contentJson', () async {
      const delta = '[{"insert":"Hello\\n"}]';
      final id = await notes.create(title: 'Hello', contentJson: delta);
      final note = await notes.getById(id);

      expect(note, isNotNull);
      expect(note!.title, 'Hello');
      expect(note.contentJson, delta);
      expect(note.isLocked, isFalse);
      expect(note.contentCiphertext, isNull);

      note.title = 'Updated';
      await notes.update(note);

      expect((await notes.getById(id))!.title, 'Updated');
      expect(await notes.delete(id), isTrue);
      expect(await notes.getById(id), isNull);
    });

    test('links notes to folders and tags', () async {
      final folderId = await folders.create(name: 'Personal');
      final tagA = await tags.createOrGet('life');
      final tagB = await tags.createOrGet('todo');

      final noteId = await notes.create(
        title: 'Groceries',
        folderId: folderId,
        tagIds: [tagA, tagB],
      );

      final byFolder = await notes.getByFolderId(folderId);
      final byTag = await notes.getByTagId(tagA);
      final note = await notes.getById(noteId);

      expect(byFolder.map((n) => n.id), contains(noteId));
      expect(byTag.map((n) => n.id), contains(noteId));
      expect(note!.folderId, folderId);
      expect(note.tagIds, containsAll([tagA, tagB]));
    });

    test('stores media path metadata without binary payloads', () async {
      final media = MediaRef()
        ..relativePath = 'images/sample.jpg'
        ..kind = 'image'
        ..createdAt = DateTime.now();

      final id = await notes.create(
        title: 'With image',
        mediaRefs: [media],
      );
      final note = await notes.getById(id);

      expect(note!.mediaRefs, hasLength(1));
      expect(note.mediaRefs.first.relativePath, 'images/sample.jpg');
      expect(note.mediaRefs.first.kind, 'image');
    });

    test('keeps encryption fields available for locked notes', () async {
      final id = await notes.create(title: 'Secret', isLocked: true);
      final note = await notes.getById(id);
      expect(note!.isLocked, isTrue);

      note
        ..contentJson = ''
        ..contentCiphertext = 'ciphertext-placeholder'
        ..encryptionSalt = 'salt'
        ..encryptionNonce = 'nonce'
        ..passwordVerifier = 'verifier';
      await notes.update(note);

      final stored = await notes.getById(id);
      expect(stored!.contentCiphertext, 'ciphertext-placeholder');
      expect(stored.encryptionSalt, 'salt');
      expect(stored.encryptionNonce, 'nonce');
      expect(stored.passwordVerifier, 'verifier');
      expect(stored.contentJson, isEmpty);
    });

    test('searches notes by title', () async {
      await notes.create(title: 'Flutter tips');
      await notes.create(title: 'Grocery list');

      final results = await notes.searchByTitle('flutter');
      expect(results, hasLength(1));
      expect(results.first.title, 'Flutter tips');
    });

    test('persists quill delta content across update/reload', () async {
      final doc = NoteContentCodec.documentFromJson(
        NoteContentCodec.emptyDeltaJson(),
      )..insert(0, 'Bold-ready body');
      final deltaJson = NoteContentCodec.encodeDocument(doc);

      final id = await notes.create(
        title: 'Delta note',
        contentJson: deltaJson,
      );
      final loaded = await notes.getById(id);
      expect(loaded, isNotNull);
      expect(
        NoteContentCodec.plainTextPreview(loaded!.contentJson),
        contains('Bold-ready body'),
      );

      final edited = NoteContentCodec.documentFromJson(loaded.contentJson)
        ..insert(0, 'Updated ');
      loaded
        ..title = 'Delta note edited'
        ..contentJson = NoteContentCodec.encodeDocument(edited);
      await notes.update(loaded);

      final reloaded = await notes.getById(id);
      expect(reloaded!.title, 'Delta note edited');
      expect(
        NoteContentCodec.plainTextPreview(reloaded.contentJson),
        contains('Updated'),
      );
    });

    test('keeps locked content stored while marking isLocked', () async {
      final doc = NoteContentCodec.documentFromJson(
        NoteContentCodec.emptyDeltaJson(),
      )..insert(0, 'secret-body');
      final id = await notes.create(
        title: 'Locked',
        contentJson: NoteContentCodec.encodeDocument(doc),
        isLocked: true,
      );
      final note = await notes.getById(id);
      expect(note!.isLocked, isTrue);
      expect(note.contentJson, contains('secret-body'));
    });
  });
}
