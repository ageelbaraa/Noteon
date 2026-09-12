import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:noteon/core/crypto/note_crypto_service.dart';
import 'package:noteon/core/database/isar_database.dart';
import 'package:noteon/core/media/media_storage_service.dart';
import 'package:noteon/features/folders/data/folder.dart';
import 'package:noteon/features/notes/data/note.dart';
import 'package:noteon/features/notes/data/note_content_codec.dart';
import 'package:noteon/features/notes/data/note_lock_service.dart';
import 'package:noteon/features/notes/data/note_repository.dart';
import 'package:noteon/features/notes/domain/notes_query.dart';
import 'package:noteon/features/tags/data/tag.dart';
import 'package:path/path.dart' as p;

import '../support/isar_test_helper.dart';

void main() {
  late Directory tempDir;
  late Directory mediaRoot;
  late MediaStorageService media;
  late NoteRepository notes;
  late NoteLockService lockService;
  late NoteCryptoService crypto;

  setUpAll(() async {
    await initializeIsarForTests();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('noteon_lock_');
    mediaRoot = Directory(p.join(tempDir.path, 'media'));
    await mediaRoot.create(recursive: true);
    media = MediaStorageService(rootOverride: mediaRoot);
    crypto = NoteCryptoService(
      config: const NoteCryptoConfig(pbkdf2Iterations: 1000),
    );
    lockService = NoteLockService(crypto: crypto, media: media);

    final dbDir = Directory(p.join(tempDir.path, 'db'));
    await dbDir.create(recursive: true);
    final isar = await IsarDatabase.openInDirectory(
      dbDir.path,
      name: 'noteon_lock_${DateTime.now().microsecondsSinceEpoch}',
    );
    notes = NoteRepository(isar, mediaStorage: media);
  });

  tearDown(() async {
    await IsarDatabase.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  String bodyWithSecret(String secret) {
    final doc = NoteContentCodec.documentFromJson(
      NoteContentCodec.emptyDeltaJson(),
    )..insert(0, secret);
    return NoteContentCodec.encodeDocument(doc);
  }

  Uint8List samplePng() {
    final image = img.Image(width: 16, height: 12);
    img.fill(image, color: img.ColorRgb8(10, 20, 30));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('locking removes persistent plaintext content', () async {
    final contentJson = bodyWithSecret('Top secret body text');
    final id = await notes.create(title: 'Secret', contentJson: contentJson);
    final note = (await notes.getById(id))!;

    await lockService.lockNote(
      note: note,
      password: 'lock-me-now',
      contentJson: contentJson,
      mediaRefs: const [],
    );
    await notes.update(note);

    final stored = (await notes.getById(id))!;
    expect(stored.isLocked, isTrue);
    expect(stored.contentJson, isEmpty);
    expect(stored.contentCiphertext, isNotNull);
    expect(stored.encryptionSalt, isNotNull);
    expect(stored.encryptionNonce, isNotNull);
    expect(stored.passwordVerifier, isNotNull);
    expect(stored.contentJson.contains('Top secret'), isFalse);
    expect(stored.contentCiphertext!.contains('Top secret'), isFalse);
  });

  test('unlock restores original Quill content; wrong password rejected',
      () async {
    final contentJson = bodyWithSecret('Recoverable delta text');
    final id = await notes.create(title: 'A', contentJson: contentJson);
    final note = (await notes.getById(id))!;

    await lockService.lockNote(
      note: note,
      password: 'good-password',
      contentJson: contentJson,
      mediaRefs: const [],
    );
    await notes.update(note);

    expect(
      () => lockService.unlockNote(note: note, password: 'bad-password'),
      throwsA(isA<NoteCryptoException>()),
    );

    final session = await lockService.unlockNote(
      note: note,
      password: 'good-password',
    );
    expect(session.contentJson, contentJson);
    expect(
      NoteContentCodec.plainTextPreview(session.contentJson),
      contains('Recoverable delta text'),
    );

    // Disk must still be encrypted after unlock (memory-only session).
    final stored = (await notes.getById(id))!;
    expect(stored.isLocked, isTrue);
    expect(stored.contentJson, isEmpty);
  });

  test('remove-lock persists plaintext and clears crypto fields', () async {
    final contentJson = bodyWithSecret('After unlock forever');
    final id = await notes.create(title: 'B', contentJson: contentJson);
    var note = (await notes.getById(id))!;

    await lockService.lockNote(
      note: note,
      password: 'remove-me',
      contentJson: contentJson,
      mediaRefs: const [],
    );
    await notes.update(note);

    final session = await lockService.unlockNote(
      note: note,
      password: 'remove-me',
    );
    await lockService.removePassword(
      note: note,
      session: session,
      contentJson: session.contentJson,
      mediaRefs: session.mediaRefs,
    );
    await notes.update(note);

    note = (await notes.getById(id))!;
    expect(note.isLocked, isFalse);
    expect(note.contentCiphertext, isNull);
    expect(note.encryptionSalt, isNull);
    expect(note.encryptionNonce, isNull);
    expect(note.passwordVerifier, isNull);
    expect(note.contentJson, contentJson);
  });

  test('locked notes are excluded from plaintext body search', () async {
    final secretBody = bodyWithSecret('needle-in-a-haystack');
    final unlocked = Note()
      ..id = 1
      ..title = 'Open'
      ..contentJson = secretBody
      ..isLocked = false
      ..updatedAt = DateTime.now();
    final locked = Note()
      ..id = 2
      ..title = 'Closed'
      ..contentJson = ''
      ..isLocked = true
      ..contentCiphertext = base64Encode(utf8.encode('ciphertext-not-searchable'))
      ..updatedAt = DateTime.now();

    final matches = NotesQuery.apply(
      notes: [unlocked, locked],
      folders: const <Folder>[],
      tags: const <Tag>[],
      query: 'needle-in-a-haystack',
    );
    expect(matches.map((n) => n.id), [1]);

    final byTitle = NotesQuery.apply(
      notes: [unlocked, locked],
      folders: const <Folder>[],
      tags: const <Tag>[],
      query: 'Closed',
    );
    expect(byTitle.map((n) => n.id), [2]);
  });

  test('locked note with image remains protected on disk', () async {
    final sketch = await media.importSketchPng(samplePng());
    final contentJson = jsonEncode([
      {'insert': 'Photo note\n'},
      {
        'insert': {'image': sketch.relativePath},
      },
      {'insert': '\n'},
    ]);

    final id = await notes.create(
      title: 'Media',
      contentJson: contentJson,
      mediaRefs: [sketch],
    );
    final note = (await notes.getById(id))!;

    expect(await media.fileFor(sketch.relativePath), isNotNull);

    await lockService.lockNote(
      note: note,
      password: 'media-pass',
      contentJson: contentJson,
      mediaRefs: [sketch],
    );
    await notes.update(note);

    expect(await media.fileFor(sketch.relativePath), isNull);
    final lockedFiles =
        await media.listLockedMediaRelativePaths(note.id);
    expect(lockedFiles, isNotEmpty);

    // Ciphertext file should not contain recognizable PNG header as plaintext.
    final enc = await media.fileFor(lockedFiles.first);
    final encBytes = await enc!.readAsBytes();
    expect(encBytes.length, greaterThan(16));
    // PNG magic is 89 50 4E 47 — must not appear at start of sealed file.
    expect(encBytes[0], isNot(0x89));

    final session = await lockService.unlockNote(
      note: note,
      password: 'media-pass',
    );
    expect(session.mediaBytes.containsKey(sketch.relativePath), isTrue);
    expect(session.contentJson, contentJson);
    // Still no plaintext file after unlock.
    expect(await media.fileFor(sketch.relativePath), isNull);
  });

  test('delete locked note cleans up encrypted media', () async {
    final sketch = await media.importSketchPng(samplePng());
    final contentJson = jsonEncode([
      {
        'insert': {'image': sketch.relativePath},
      },
      {'insert': '\n'},
    ]);

    final id = await notes.create(
      title: 'Del',
      contentJson: contentJson,
      mediaRefs: [sketch],
    );
    final note = (await notes.getById(id))!;
    await lockService.lockNote(
      note: note,
      password: 'bye-media',
      contentJson: contentJson,
      mediaRefs: [sketch],
    );
    await notes.update(note);

    final before = await media.listLockedMediaRelativePaths(id);
    expect(before, isNotEmpty);

    await notes.delete(id);
    expect(await notes.getById(id), isNull);
    expect(await media.listLockedMediaRelativePaths(id), isEmpty);
    expect(await media.fileFor(sketch.relativePath), isNull);
  });

  test('reloading locked note does not expose decrypted content', () async {
    final contentJson = bodyWithSecret('session must die');
    final id = await notes.create(title: 'Restart', contentJson: contentJson);
    final note = (await notes.getById(id))!;
    await lockService.lockNote(
      note: note,
      password: 'persist',
      contentJson: contentJson,
      mediaRefs: const [],
    );
    await notes.update(note);

    // Simulate app restart: only DB reload, no session.
    final reloaded = (await notes.getById(id))!;
    expect(reloaded.isLocked, isTrue);
    expect(reloaded.contentJson, isEmpty);
    expect(reloaded.contentJson.contains('session must die'), isFalse);
    expect(
      NoteContentCodec.plainTextPreview(reloaded.contentJson),
      isEmpty,
    );
  });
}
