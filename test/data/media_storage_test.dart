import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:noteon/core/database/isar_database.dart';
import 'package:noteon/core/media/media_storage_service.dart';
import 'package:noteon/features/notes/data/note_media_paths.dart';
import 'package:noteon/features/notes/data/note_repository.dart';
import 'package:path/path.dart' as p;

import '../support/isar_test_helper.dart';

void main() {
  late Directory tempDir;
  late Directory mediaRoot;
  late MediaStorageService media;
  late NoteRepository notes;

  setUpAll(() async {
    await initializeIsarForTests();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('noteon_media_');
    mediaRoot = Directory(p.join(tempDir.path, 'media'));
    await mediaRoot.create(recursive: true);
    media = MediaStorageService(rootOverride: mediaRoot);

    final dbDir = Directory(p.join(tempDir.path, 'db'));
    await dbDir.create(recursive: true);
    final isar = await IsarDatabase.openInDirectory(
      dbDir.path,
      name: 'noteon_media_${DateTime.now().microsecondsSinceEpoch}',
    );
    notes = NoteRepository(isar, mediaStorage: media);
  });

  tearDown(() async {
    await IsarDatabase.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Uint8List samplePngBytes() {
    final image = img.Image(width: 32, height: 24);
    img.fill(image, color: img.ColorRgb8(12, 148, 136));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('imports image into private storage with relative MediaRef', () async {
    final source = File(p.join(tempDir.path, 'source.png'));
    await source.writeAsBytes(samplePngBytes());

    final ref = await media.importImageFile(source);
    expect(ref.kind, 'image');
    expect(ref.relativePath.startsWith('images/'), isTrue);

    final stored = await media.fileFor(ref.relativePath);
    expect(stored, isNotNull);
    expect(await stored!.exists(), isTrue);
  });

  test('reconcile removes orphaned media files', () async {
    final source = File(p.join(tempDir.path, 'a.png'));
    await source.writeAsBytes(samplePngBytes());
    final keep = await media.importImageFile(source);
    final drop = await media.importImageFile(source);

    final reconciled = await media.reconcile(
      previous: [keep, drop],
      liveRelativePaths: [keep.relativePath],
    );

    expect(reconciled, hasLength(1));
    expect(reconciled.first.relativePath, keep.relativePath);
    expect(await media.fileFor(drop.relativePath), isNull);
    expect(await media.fileFor(keep.relativePath), isNotNull);
  });

  test('deleting a note removes its media files', () async {
    final source = File(p.join(tempDir.path, 'note.png'));
    await source.writeAsBytes(samplePngBytes());
    final ref = await media.importImageFile(source);

    final contentJson =
        '[{"insert":{"image":"${ref.relativePath}"}},{"insert":"\\n"}]';

    final id = await notes.create(
      title: 'With image',
      contentJson: contentJson,
      mediaRefs: [ref],
    );

    expect(await media.fileFor(ref.relativePath), isNotNull);
    expect(await notes.delete(id), isTrue);
    expect(await media.fileFor(ref.relativePath), isNull);
    expect(await notes.getById(id), isNull);
  });

  test('NoteMediaPaths extracts image paths from delta json', () {
    const json =
        '[{"insert":"Hi"},{"insert":{"image":"images/a.jpg"}},{"insert":"\\n"}]';
    expect(NoteMediaPaths.extractFromContentJson(json), ['images/a.jpg']);
  });

  test('imports sketch png under sketches/ with kind sketch', () async {
    final ref = await media.importSketchPng(samplePngBytes());
    expect(ref.kind, 'sketch');
    expect(ref.relativePath.startsWith('sketches/'), isTrue);
    expect(ref.relativePath.endsWith('.png'), isTrue);

    final stored = await media.fileFor(ref.relativePath);
    expect(stored, isNotNull);
    expect(await stored!.exists(), isTrue);
  });

  test('deleting a note removes its sketch files', () async {
    final ref = await media.importSketchPng(samplePngBytes());
    final contentJson =
        '[{"insert":{"image":"${ref.relativePath}"}},{"insert":"\\n"}]';

    final id = await notes.create(
      title: 'With sketch',
      contentJson: contentJson,
      mediaRefs: [ref],
    );

    expect(await notes.delete(id), isTrue);
    expect(await media.fileFor(ref.relativePath), isNull);
  });

  test('reconcile drops removed sketch files', () async {
    final keep = await media.importSketchPng(samplePngBytes());
    final drop = await media.importSketchPng(samplePngBytes());

    final reconciled = await media.reconcile(
      previous: [keep, drop],
      liveRelativePaths: [keep.relativePath],
    );

    expect(reconciled.map((r) => r.relativePath), [keep.relativePath]);
    expect(reconciled.first.kind, 'sketch');
    expect(await media.fileFor(drop.relativePath), isNull);
  });
}
