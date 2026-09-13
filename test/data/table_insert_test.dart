import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/features/notes/data/noteon_table_data.dart';
import 'package:noteon/features/notes/presentation/noteon_table_embed.dart';

int countTableEmbeds(Document doc) {
  var count = 0;
  for (final op in doc.toDelta().toList()) {
    final data = op.data;
    if (data is! Map) {
      continue;
    }
    if (data.containsKey('noteonTable')) {
      count++;
    }
    final custom = data['custom'];
    if (custom is String && custom.contains('noteonTable')) {
      count++;
    }
  }
  return count;
}

/// Mirrors [NoteEditorScreen._insertBlockEmbed] newline heuristics.
void insertBlockEmbed(QuillController controller, Embeddable embed) {
  final document = controller.document;
  var index = controller.selection.isValid
      ? controller.selection.baseOffset
      : document.length - 1;
  index = index.clamp(0, document.length - 1);

  final itr = DeltaIterator(document.toDelta());
  final prev = index > 0 ? itr.skip(index) : null;
  final cur = itr.next();
  final textBefore =
      prev != null && prev.data is String ? prev.data as String : '';
  final textAfter = cur.data is String ? cur.data as String : '';
  final isNewlineBefore = prev == null || textBefore.endsWith('\n');
  final isNewlineAfter = textAfter.startsWith('\n');

  if (!isNewlineBefore) {
    controller.replaceText(
      index,
      0,
      '\n',
      TextSelection.collapsed(offset: index + 1),
    );
    index += 1;
  }

  controller.replaceText(
    index,
    0,
    embed,
    TextSelection.collapsed(offset: index + 1),
  );

  if (!isNewlineAfter) {
    controller.replaceText(
      index + 1,
      0,
      '\n',
      TextSelection.collapsed(offset: index + 2),
    );
  }
}

void main() {
  test('inserting a table once keeps a single embed', () {
    final controller = QuillController.basic();
    final table = NoteonTableData.empty(rows: 2, columns: 2);
    insertBlockEmbed(
      controller,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
    );
    expect(countTableEmbeds(controller.document), 1);
  });

  test('insert after existing text keeps a single embed', () {
    final controller = QuillController(
      document: Document.fromJson([
        {'insert': 'Hello world\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 11),
    );
    final table = NoteonTableData.empty(rows: 2, columns: 2);
    insertBlockEmbed(
      controller,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
    );
    expect(countTableEmbeds(controller.document), 1);
    expect(NoteonTableDocument.offsetOf(controller.document, table.id), isNotNull);
  });

  test('stale documentOffset 0 must not create a second table on commit', () {
    final controller = QuillController(
      document: Document.fromJson([
        {'insert': 'Preface text\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 12),
    );
    final table = NoteonTableData.empty(rows: 2, columns: 2);
    insertBlockEmbed(
      controller,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
    );
    expect(countTableEmbeds(controller.document), 1);

    final realOffset = NoteonTableDocument.offsetOf(controller.document, table.id)!;
    expect(realOffset, greaterThan(0));

    // Bug path: custom embeds often report documentOffset == 0.
    const staleOffset = 0;
    final updated = table.copyWithCell(0, 0, 'Hi');
    // Correct path uses id lookup (never staleOffset).
    final offset = NoteonTableDocument.offsetOf(controller.document, updated.id);
    expect(offset, realOffset);
    controller.replaceText(
      offset!,
      1,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(updated)),
      TextSelection.collapsed(offset: offset + 1),
    );
    expect(countTableEmbeds(controller.document), 1);

    // Demonstrate the old bug: replace at 0 inserts a duplicate.
    final buggy = QuillController(
      document: Document.fromJson(controller.document.toDelta().toJson()),
      selection: const TextSelection.collapsed(offset: 0),
    );
    buggy.replaceText(
      staleOffset,
      1,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(updated)),
      const TextSelection.collapsed(offset: 1),
    );
    expect(countTableEmbeds(buggy.document), 2);
  });

  test('double insert without guard creates two embeds', () {
    final controller = QuillController.basic();
    final table = NoteonTableData.empty(rows: 2, columns: 2);
    final block = BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table));
    insertBlockEmbed(controller, block);
    insertBlockEmbed(controller, block);
    expect(countTableEmbeds(controller.document), 2);
  });
}
