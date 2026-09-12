import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/features/folders/data/folder.dart';
import 'package:noteon/features/notes/data/note.dart';
import 'package:noteon/features/notes/data/note_content_codec.dart';
import 'package:noteon/features/notes/domain/note_date_grouper.dart';
import 'package:noteon/features/notes/domain/notes_query.dart';
import 'package:noteon/features/tags/data/tag.dart';

void main() {
  group('NoteDateGrouper', () {
    test('buckets notes by updatedAt', () {
      final now = DateTime(2026, 9, 12, 18);
      final today = Note()
        ..title = 'today'
        ..updatedAt = DateTime(2026, 9, 12, 10);
      final yesterday = Note()
        ..title = 'yesterday'
        ..updatedAt = DateTime(2026, 9, 11, 9);
      final thisWeek = Note()
        ..title = 'week'
        ..updatedAt = DateTime(2026, 9, 9, 9); // Tuesday if Sat is 12th
      final older = Note()
        ..title = 'older'
        ..updatedAt = DateTime(2026, 8, 1);

      final sections = NoteDateGrouper.group(
        [today, yesterday, thisWeek, older],
        now: now,
      );

      expect(
        sections.map((s) => s.bucket).toList(),
        [
          NoteDateBucket.today,
          NoteDateBucket.yesterday,
          NoteDateBucket.thisWeek,
          NoteDateBucket.older,
        ],
      );
      expect(sections.first.notes.single.title, 'today');
      expect(sections.last.notes.single.title, 'older');
    });
  });

  group('NotesQuery', () {
    test('filters by folder, tag, and multi-field search', () {
      final folder = Folder()
        ..id = 1
        ..name = 'Work';
      final tag = Tag()
        ..id = 7
        ..name = 'urgent';

      final body = NoteContentCodec.encodeDocument(
        NoteContentCodec.documentFromJson(NoteContentCodec.emptyDeltaJson())
          ..insert(0, 'Quarterly report draft'),
      );

      final matching = Note()
        ..id = 1
        ..title = 'Planning'
        ..contentJson = body
        ..folderId = 1
        ..tagIds = [7]
        ..updatedAt = DateTime.now();

      final locked = Note()
        ..id = 2
        ..title = 'Secret'
        ..contentJson = body
        ..isLocked = true
        ..folderId = 1
        ..updatedAt = DateTime.now();

      final other = Note()
        ..id = 3
        ..title = 'Groceries'
        ..contentJson = NoteContentCodec.emptyDeltaJson()
        ..updatedAt = DateTime.now();

      final byFolder = NotesQuery.apply(
        notes: [matching, other],
        folders: [folder],
        tags: [tag],
        folderId: 1,
      );
      expect(byFolder.map((n) => n.id), [1]);

      final byTag = NotesQuery.apply(
        notes: [matching, other],
        folders: [folder],
        tags: [tag],
        tagId: 7,
      );
      expect(byTag.map((n) => n.id), [1]);

      final byBody = NotesQuery.apply(
        notes: [matching, locked, other],
        folders: [folder],
        tags: [tag],
        query: 'quarterly',
      );
      expect(byBody.map((n) => n.id), [1]);

      final byFolderName = NotesQuery.apply(
        notes: [matching, other],
        folders: [folder],
        tags: [tag],
        query: 'work',
      );
      expect(byFolderName.map((n) => n.id), [1]);

      final byTagName = NotesQuery.apply(
        notes: [matching, other],
        folders: [folder],
        tags: [tag],
        query: 'urgent',
      );
      expect(byTagName.map((n) => n.id), [1]);
    });

    test('unfiledOnly excludes notes with a folder', () {
      final filed = Note()
        ..id = 1
        ..folderId = 3
        ..updatedAt = DateTime.now();
      final unfiled = Note()
        ..id = 2
        ..updatedAt = DateTime.now();

      final result = NotesQuery.apply(
        notes: [filed, unfiled],
        folders: const [],
        tags: const [],
        unfiledOnly: true,
      );
      expect(result.map((n) => n.id), [2]);
    });
  });
}
