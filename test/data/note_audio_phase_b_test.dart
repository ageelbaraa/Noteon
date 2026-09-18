import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/media/media_storage_service.dart';
import 'package:noteon/features/notes/data/note_block_model.dart';
import 'package:noteon/features/notes/data/note_content_codec.dart';
import 'package:noteon/features/notes/data/note_media_paths.dart';
import 'package:noteon/features/notes/data/noteon_audio_payload.dart';
import 'package:noteon/features/notes/presentation/noteon_audio_embed.dart';

void main() {
  test('audio payload round-trips path and duration', () {
    final raw = NoteonAudioPayload.encode(
      path: 'audio/clip.m4a',
      durationMs: 1500,
    );
    final decoded = NoteonAudioPayload.decode(raw);
    expect(decoded.path, 'audio/clip.m4a');
    expect(decoded.durationMs, 1500);
  });

  test('NoteMediaPaths extracts image and audio embeds', () {
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      BlockEmbed.image('images/a.jpg'),
      const TextSelection.collapsed(offset: 1),
    );
    controller.replaceText(
      1,
      0,
      '\n',
      const TextSelection.collapsed(offset: 2),
    );
    controller.replaceText(
      2,
      0,
      BlockEmbed.custom(
        NoteonAudioBlockEmbed.fromPayload(
          path: 'audio/b.m4a',
          durationMs: 900,
        ),
      ),
      const TextSelection.collapsed(offset: 3),
    );

    final json = NoteContentCodec.encodeDocument(controller.document);
    final paths = NoteMediaPaths.extractFromContentJson(json);
    expect(paths, ['images/a.jpg', 'audio/b.m4a']);
    expect(NoteContentCodec.isBlankNote(title: '', contentJson: json), isFalse);
  });

  test('listBlocks includes audio embeds', () {
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      BlockEmbed.custom(
        NoteonAudioBlockEmbed.fromPayload(path: 'audio/x.m4a'),
      ),
      const TextSelection.collapsed(offset: 1),
    );
    final blocks = NoteBlockModel.listBlocks(controller.document);
    expect(blocks.single.kind, NoteBlockKind.audio);
    expect(blocks.single.audioPath, 'audio/x.m4a');
  });

  test('kindForRelativePath recognizes audio subdirectory', () {
    expect(
      MediaStorageService.kindForRelativePath('audio/a.m4a'),
      'audio',
    );
    expect(
      MediaStorageService.kindForRelativePath('sketches/a.png'),
      'sketch',
    );
    expect(
      MediaStorageService.kindForRelativePath('images/a.jpg'),
      'image',
    );
  });

  test('legacy content without audio still extracts images only', () {
    final json = jsonEncode([
      {
        'insert': {'image': 'images/legacy.jpg'},
      },
      {'insert': '\n'},
    ]);
    expect(NoteMediaPaths.extractFromContentJson(json), ['images/legacy.jpg']);
  });
}
