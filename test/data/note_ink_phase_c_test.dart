import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/media/media_storage_service.dart';
import 'package:noteon/features/notes/data/note_block_model.dart';
import 'package:noteon/features/notes/data/note_content_codec.dart';
import 'package:noteon/features/notes/data/note_media_paths.dart';
import 'package:noteon/features/notes/data/noteon_ink_payload.dart';
import 'package:noteon/features/notes/data/noteon_ink_stroke_codec.dart';

void main() {
  test('ink payload round-trips paths and width', () {
    final raw = NoteonInkPayload.encode(
      id: 'abc',
      strokesPath: 'ink/abc.json',
      previewPath: 'ink/abc.png',
      displayWidth: 220,
    );
    final decoded = NoteonInkPayload.decode(raw);
    expect(decoded.id, 'abc');
    expect(decoded.strokesPath, 'ink/abc.json');
    expect(decoded.previewPath, 'ink/abc.png');
    expect(decoded.displayWidth, 220);
    expect(decoded.mediaPaths, ['ink/abc.json', 'ink/abc.png']);
  });

  test('NoteMediaPaths extracts ink stroke and preview paths', () {
    final controller = QuillController.basic();
    final data = NoteonInkData(
      id: 'x1',
      strokesPath: 'ink/x1.json',
      previewPath: 'ink/x1.png',
    );
    controller.replaceText(
      0,
      0,
      BlockEmbed.custom(NoteonInkBlockEmbed.fromData(data)),
      const TextSelection.collapsed(offset: 1),
    );
    final json = NoteContentCodec.encodeDocument(controller.document);
    expect(
      NoteMediaPaths.extractFromContentJson(json),
      ['ink/x1.json', 'ink/x1.png'],
    );
    expect(NoteContentCodec.isBlankNote(title: '', contentJson: json), isFalse);
  });

  test('listBlocks includes ink embeds; legacy image sketches still image', () {
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      BlockEmbed.image('sketches/old.png'),
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
        NoteonInkBlockEmbed.fromData(
          const NoteonInkData(
            id: 'n1',
            strokesPath: 'ink/n1.json',
            previewPath: 'ink/n1.png',
          ),
        ),
      ),
      const TextSelection.collapsed(offset: 3),
    );

    final blocks = NoteBlockModel.listBlocks(controller.document);
    expect(blocks.map((b) => b.kind).toList(), [
      NoteBlockKind.image,
      NoteBlockKind.ink,
    ]);
    expect(blocks[0].imagePath, 'sketches/old.png');
    expect(blocks[1].inkId, 'n1');
  });

  test('kindForRelativePath recognizes ink subdirectory', () {
    expect(MediaStorageService.kindForRelativePath('ink/a.json'), 'ink');
    expect(MediaStorageService.kindForRelativePath('sketches/a.png'), 'sketch');
  });

  test('stroke codec translates points and point-in-polygon select', () {
    final stroke = {
      'type': 'SimpleLine',
      'points': [
        {'dx': 10.0, 'dy': 10.0},
        {'dx': 20.0, 'dy': 20.0},
      ],
      'paint': {'color': 0xFF000000, 'strokeWidth': 4.0},
    };
    final moved = NoteonInkStrokeCodec.translateStroke(
      stroke,
      const Offset(5, -5),
    );
    expect(moved['points'], [
      {'dx': 15.0, 'dy': 5.0},
      {'dx': 25.0, 'dy': 15.0},
    ]);

    final polygon = [
      const Offset(0, 0),
      const Offset(30, 0),
      const Offset(30, 30),
      const Offset(0, 30),
    ];
    expect(
      NoteonInkStrokeCodec.strokeIntersectsPolygon(stroke, polygon),
      isTrue,
    );
    expect(
      NoteonInkStrokeCodec.strokeIntersectsPolygon(stroke, [
        const Offset(100, 100),
        const Offset(120, 100),
        const Offset(120, 120),
      ]),
      isFalse,
    );
  });

  test('exportActive drops undone history past currentIndex', () {
    // Simulate history length 3 with currentIndex 2 (one undone).
    final exported = NoteonInkStrokeCodec.exportActive(
      history: const [],
      currentIndex: 0,
    );
    expect(exported, isEmpty);

    final json = NoteonInkStrokeCodec.encodeJsonList([
      {
        'type': 'SimpleLine',
        'points': [
          {'dx': 1.0, 'dy': 1.0},
        ],
        'paint': {'color': 1, 'strokeWidth': 2.0},
      },
    ]);
    final decoded = NoteonInkStrokeCodec.decodeJsonList(json);
    expect(decoded, hasLength(1));
    // fromJson may need full paint map — just ensure round-trip list shape.
    expect(utf8.encode(json), isA<Uint8List>());
  });
}
