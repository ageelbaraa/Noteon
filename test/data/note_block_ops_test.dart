import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/features/notes/data/note_block_model.dart';
import 'package:noteon/features/notes/data/note_block_ops.dart';
import 'package:noteon/features/notes/data/note_media_paths.dart';
import 'package:noteon/features/notes/data/noteon_table_data.dart';
import 'package:noteon/features/notes/presentation/noteon_table_embed.dart';

void main() {
  test('listBlocks orders text, image, table without whitespace-only gaps', () {
    final table = NoteonTableData.empty(rows: 2, columns: 2)
        .copyWithCell(0, 0, 'Cell A');
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      'Hello\n',
      const TextSelection.collapsed(offset: 6),
    );
    controller.replaceText(
      6,
      0,
      BlockEmbed.image('noteon_media/a.jpg'),
      const TextSelection.collapsed(offset: 7),
    );
    controller.replaceText(
      7,
      0,
      '\nWorld\n',
      const TextSelection.collapsed(offset: 14),
    );
    controller.replaceText(
      14,
      0,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
      const TextSelection.collapsed(offset: 15),
    );

    final blocks = NoteBlockModel.listBlocks(controller.document);
    expect(blocks.map((b) => b.kind).toList(), [
      NoteBlockKind.text,
      NoteBlockKind.image,
      NoteBlockKind.text,
      NoteBlockKind.table,
    ]);
    expect(blocks[1].imagePath, 'noteon_media/a.jpg');
    expect(blocks[3].tableId, table.id);
  });

  test('moveBlock relocates image without duplicating or losing table cells', () {
    final table = NoteonTableData.empty(rows: 2, columns: 2)
        .copyWithCell(0, 0, 'Keep me');
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      'Intro\n',
      const TextSelection.collapsed(offset: 6),
    );
    controller.replaceText(
      6,
      0,
      BlockEmbed.image('noteon_media/pic.png'),
      const TextSelection.collapsed(offset: 7),
    );
    controller.replaceText(
      7,
      0,
      '\n',
      const TextSelection.collapsed(offset: 8),
    );
    controller.replaceText(
      8,
      0,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
      const TextSelection.collapsed(offset: 9),
    );

    var blocks = NoteBlockModel.listBlocks(controller.document);
    expect(blocks.map((b) => b.kind).toList(), [
      NoteBlockKind.text,
      NoteBlockKind.image,
      NoteBlockKind.table,
    ]);

    // Move image before intro text (toIndex 0).
    final newIndex = NoteBlockOps.moveBlock(
      controller,
      fromIndex: 1,
      toIndex: 0,
    );
    expect(newIndex, isNotNull);

    blocks = NoteBlockModel.listBlocks(controller.document);
    expect(blocks.map((b) => b.kind).toList(), [
      NoteBlockKind.image,
      NoteBlockKind.text,
      NoteBlockKind.table,
    ]);
    expect(blocks.where((b) => b.kind == NoteBlockKind.image).length, 1);
    expect(blocks.where((b) => b.kind == NoteBlockKind.table).length, 1);

    // Table cells preserved.
    NoteonTableData? found;
    for (final op in controller.document.toDelta().toList()) {
      final data = op.data;
      if (data is Map && data['custom'] is String) {
        found = NoteonTableBlockEmbed.tryParseEmbeddable(
          Embeddable.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    }
    expect(found, isNotNull);
    expect(found!.cells[0][0], 'Keep me');
    expect(found.id, table.id);
  });

  test('deleteBlock removes only the image embed', () {
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      'Before\n',
      const TextSelection.collapsed(offset: 7),
    );
    controller.replaceText(
      7,
      0,
      BlockEmbed.image('noteon_media/x.jpg'),
      const TextSelection.collapsed(offset: 8),
    );
    controller.replaceText(
      8,
      0,
      '\nAfter\n',
      const TextSelection.collapsed(offset: 15),
    );

    final blocks = NoteBlockModel.listBlocks(controller.document);
    final image = blocks.firstWhere((b) => b.kind == NoteBlockKind.image);
    expect(NoteBlockOps.deleteBlock(controller, image), isTrue);

    final after = NoteBlockModel.listBlocks(controller.document);
    expect(after.any((b) => b.kind == NoteBlockKind.image), isFalse);
    expect(controller.document.toPlainText().contains('Before'), isTrue);
    expect(controller.document.toPlainText().contains('After'), isTrue);
    expect(NoteMediaPaths.extractFromDocument(controller.document), isEmpty);
  });

  test('setImageDisplayWidth persists width; legacy path still extracts', () {
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      BlockEmbed.image('noteon_media/legacy.jpg'),
      const TextSelection.collapsed(offset: 1),
    );

    expect(
      NoteMediaPaths.extractFromDocument(controller.document),
      ['noteon_media/legacy.jpg'],
    );

    final blocks = NoteBlockModel.listBlocks(controller.document);
    expect(blocks.single.displayWidth, isNull);

    expect(
      NoteBlockOps.setImageDisplayWidth(
        controller,
        imageOffset: blocks.single.start,
        width: 220,
      ),
      isTrue,
    );

    final updated = NoteBlockModel.listBlocks(controller.document);
    expect(updated.single.displayWidth, 220);
    expect(
      NoteMediaPaths.extractFromDocument(controller.document),
      ['noteon_media/legacy.jpg'],
    );
  });

  test('replaceImage keeps width attribute', () {
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      BlockEmbed.image('noteon_media/old.jpg'),
      const TextSelection.collapsed(offset: 1),
    );
    NoteBlockOps.setImageDisplayWidth(
      controller,
      imageOffset: 0,
      width: 180,
    );

    expect(
      NoteBlockOps.replaceImage(
        controller,
        imageOffset: 0,
        newRelativePath: 'noteon_media/new.jpg',
      ),
      isTrue,
    );

    final blocks = NoteBlockModel.listBlocks(controller.document);
    expect(blocks.single.imagePath, 'noteon_media/new.jpg');
    expect(blocks.single.displayWidth, 180);
  });

  test('moveBlockDown / moveBlockUp keep a single table with cell data', () {
    final table = NoteonTableData.empty(rows: 1, columns: 1)
        .copyWithCell(0, 0, 'T');
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      'A\n',
      const TextSelection.collapsed(offset: 2),
    );
    controller.replaceText(
      2,
      0,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
      const TextSelection.collapsed(offset: 3),
    );
    controller.replaceText(
      3,
      0,
      '\nB\n',
      const TextSelection.collapsed(offset: 6),
    );

    var blocks = NoteBlockModel.listBlocks(controller.document);
    final tableIndex =
        blocks.indexWhere((b) => b.kind == NoteBlockKind.table);
    expect(tableIndex, 1);

    expect(NoteBlockOps.moveBlockDown(controller, tableIndex), isTrue);
    blocks = NoteBlockModel.listBlocks(controller.document);
    final afterDown = blocks.indexWhere((b) => b.kind == NoteBlockKind.table);
    expect(afterDown, isNonNegative);
    if (afterDown > 0) {
      expect(NoteBlockOps.moveBlockUp(controller, afterDown), isTrue);
    }

    blocks = NoteBlockModel.listBlocks(controller.document);
    expect(blocks.where((b) => b.kind == NoteBlockKind.table).length, 1);

    NoteonTableData? found;
    for (final op in controller.document.toDelta().toList()) {
      final data = op.data;
      if (data is Map && data['custom'] is String) {
        found = NoteonTableBlockEmbed.tryParseEmbeddable(
          Embeddable.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    }
    expect(found?.cells[0][0], 'T');
    expect(found?.id, table.id);
  });
}
