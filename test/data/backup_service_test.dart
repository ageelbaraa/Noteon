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
import 'package:noteon/features/tags/data/tag.dart';
import 'package:noteon/features/transfer/data/backup_service.dart';
import 'package:noteon/features/transfer/data/noteon_backup_codec.dart';
import 'package:noteon/features/transfer/domain/backup_models.dart';
import 'package:path/path.dart' as p;

import '../support/isar_test_helper.dart';

void main() {
  late Directory tempDir;
  late Directory mediaRoot;
  late MediaStorageService media;
  late NoteRepository notes;
  late NoteLockService lockService;
  late NoteCryptoService crypto;
  late BackupService backup;

  setUpAll(() async {
    await initializeIsarForTests();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('noteon_bak_');
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
      name: 'noteon_bak_${DateTime.now().microsecondsSinceEpoch}',
    );
    notes = NoteRepository(isar, mediaStorage: media);
    backup = BackupService(isar: isar, media: media, crypto: crypto);
  });

  tearDown(() async {
    await IsarDatabase.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  String body(String text) {
    final doc = NoteContentCodec.documentFromJson(
      NoteContentCodec.emptyDeltaJson(),
    )..insert(0, text);
    return NoteContentCodec.encodeDocument(doc);
  }

  Uint8List samplePng() {
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(1, 2, 3));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('codec round-trips header and ciphertext', () {
    final encoded = NoteonBackupCodec.encode(
      header: {'format': 'noteonbak', 'version': 1},
      ciphertextWithMac: Uint8List.fromList(List.filled(32, 7)),
    );
    final decoded = NoteonBackupCodec.decode(encoded);
    expect(decoded.version, 1);
    expect(decoded.header['format'], 'noteonbak');
    expect(decoded.ciphertextWithMac, everyElement(7));
  });

  test('export/import replace restores locked note and media', () async {
    final isar = IsarDatabase.instance;
    final folderId = await isar.writeTxn(() async {
      final folder = Folder()
        ..name = 'Work'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();
      return isar.folders.put(folder);
    });
    final tagId = await isar.writeTxn(() async {
      final tag = Tag()
        ..name = 'urgent'
        ..createdAt = DateTime.now();
      return isar.tags.put(tag);
    });

    final sketch = await media.importSketchPng(samplePng());
    final unlockedId = await notes.create(
      title: 'Open note',
      contentJson: body('Visible body'),
      folderId: folderId,
      tagIds: [tagId],
      mediaRefs: [sketch],
    );

    final lockedSketch = await media.importSketchPng(samplePng());
    final lockedContent = jsonEncode([
      {'insert': 'Secret locked body\n'},
      {
        'insert': {'image': lockedSketch.relativePath},
      },
      {'insert': '\n'},
    ]);
    final lockedId = await notes.create(
      title: 'Locked note',
      contentJson: lockedContent,
      mediaRefs: [lockedSketch],
    );
    final lockedNote = (await notes.getById(lockedId))!;
    await lockService.lockNote(
      note: lockedNote,
      password: 'note-pass',
      contentJson: lockedContent,
      mediaRefs: [lockedSketch],
    );
    await notes.update(lockedNote);

    final archive =
        await backup.exportEncryptedBackup(passphrase: 'archive-pass');
    expect(utf8.decode(archive.sublist(0, 9)), 'NOTEONBAK');

    await isar.writeTxn(() async {
      await isar.notes.clear();
      await isar.folders.clear();
      await isar.tags.clear();
    });
    await media.clearAllMedia();
    expect(await notes.getAll(), isEmpty);

    final result = await backup.importEncryptedBackup(
      fileBytes: archive,
      passphrase: 'archive-pass',
      mode: BackupImportMode.replace,
    );
    expect(result.notesImported, 2);
    expect(result.foldersImported, 1);
    expect(result.tagsImported, 1);

    final restoredNotes = await notes.getAll();
    expect(restoredNotes, hasLength(2));

    final restoredLocked =
        restoredNotes.firstWhere((n) => n.title == 'Locked note');
    expect(restoredLocked.isLocked, isTrue);
    expect(restoredLocked.contentJson, isEmpty);
    expect(restoredLocked.id, lockedId);

    final session = await lockService.unlockNote(
      note: restoredLocked,
      password: 'note-pass',
    );
    expect(session.contentJson.contains('Secret locked body'), isTrue);
    expect(session.mediaBytes, isNotEmpty);

    final restoredOpen =
        restoredNotes.firstWhere((n) => n.title == 'Open note');
    expect(restoredOpen.id, unlockedId);
    expect(restoredOpen.folderId, folderId);
    expect(restoredOpen.tagIds, [tagId]);
    expect(restoredOpen.mediaRefs, isNotEmpty);
    expect(
      await media.fileFor(restoredOpen.mediaRefs.first.relativePath),
      isNotNull,
    );
  });

  test('wrong archive passphrase is rejected', () async {
    await notes.create(title: 'A', contentJson: body('x'));
    final archive =
        await backup.exportEncryptedBackup(passphrase: 'correct-pass');

    expect(
      () => backup.openEncryptedBackup(
        fileBytes: archive,
        passphrase: 'wrong-pass',
      ),
      throwsA(
        isA<BackupException>().having(
          (e) => e.code,
          'code',
          BackupErrorCode.incorrectPassphrase,
        ),
      ),
    );
  });

  test('merge import remaps unlocked note ids and keeps locked unlockable',
      () async {
    final lockedContent = body('Merge locked secret');
    final lockedId = await notes.create(
      title: 'Locked',
      contentJson: lockedContent,
    );
    final lockedNote = (await notes.getById(lockedId))!;
    await lockService.lockNote(
      note: lockedNote,
      password: 'lock-pw',
      contentJson: lockedContent,
      mediaRefs: const [],
    );
    await notes.update(lockedNote);

    final archive =
        await backup.exportEncryptedBackup(passphrase: 'archive-pass');

    await notes.delete(lockedId);
    await notes.create(title: 'Local only', contentJson: body('keep me'));

    final result = await backup.importEncryptedBackup(
      fileBytes: archive,
      passphrase: 'archive-pass',
      mode: BackupImportMode.merge,
    );
    expect(result.notesImported, 1);

    final all = await notes.getAll();
    expect(all.any((n) => n.title == 'Local only'), isTrue);
    final mergedLocked = all.singleWhere((n) => n.title == 'Locked');
    expect(mergedLocked.isLocked, isTrue);
    expect(mergedLocked.id, isNot(lockedId));

    final session = await lockService.unlockNote(
      note: mergedLocked,
      password: 'lock-pw',
    );
    expect(session.contentJson.contains('Merge locked secret'), isTrue);
  });
}
