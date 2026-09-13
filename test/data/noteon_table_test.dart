import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/features/notes/data/note_content_codec.dart';
import 'package:noteon/features/notes/data/noteon_table_data.dart';
import 'package:noteon/features/notes/presentation/noteon_table_embed.dart';

void main() {
  group('NoteonTableData', () {
    test('round-trips json and preserves cell text', () {
      final table = NoteonTableData.empty(rows: 2, columns: 3).copyWithCell(
            0,
            0,
            'Hello',
          ).copyWithCell(1, 2, 'عالم');

      final restored = NoteonTableData.fromJsonString(table.toJsonString());
      expect(restored.rows, 2);
      expect(restored.columns, 3);
      expect(restored.cells[0][0], 'Hello');
      expect(restored.cells[1][2], 'عالم');
      expect(restored.toPlainText(), contains('Hello'));
      expect(restored.toPlainText(), contains('عالم'));
    });

    test('add/remove row and column keep bounds', () {
      var table = NoteonTableData.empty(rows: 2, columns: 2);
      table = table.addRow().addColumn();
      expect(table.rows, 3);
      expect(table.columns, 3);

      table = table.removeRow().removeColumn();
      expect(table.rows, 2);
      expect(table.columns, 2);

      table = table.removeRow().removeColumn();
      // Minimum size is 1x1.
      expect(table.rows, 1);
      expect(table.columns, 1);
      table = table.removeRow().removeColumn();
      expect(table.rows, 1);
      expect(table.columns, 1);
    });
  });

  group('table embed persistence', () {
    test('survives Document encode/decode via custom embed', () {
      final table = NoteonTableData.empty(rows: 2, columns: 2)
          .copyWithCell(0, 0, 'Title')
          .copyWithCell(1, 1, 'Value');

      final doc = Document();
      doc.insert(
        0,
        BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
      );
      final encoded = NoteContentCodec.encodeDocument(doc);
      expect(encoded, contains('noteonTable'));
      expect(encoded, contains('Title'));

      final restoredDoc = NoteContentCodec.documentFromJson(encoded);
      final restoredJson = NoteContentCodec.encodeDocument(restoredDoc);
      expect(
        NoteContentCodec.plainTextPreview(restoredJson, maxLength: 1000),
        contains('Title'),
      );
      expect(
        NoteContentCodec.plainTextPreview(restoredJson, maxLength: 1000),
        contains('Value'),
      );
      expect(
        NoteContentCodec.isBlankNote(title: '', contentJson: restoredJson),
        isFalse,
      );
    });

    test('blank note detection treats empty table as content', () {
      final emptyTable = NoteonTableData.empty(rows: 2, columns: 2);
      final doc = Document()
        ..insert(
          0,
          BlockEmbed.custom(NoteonTableBlockEmbed.fromData(emptyTable)),
        );
      final encoded = NoteContentCodec.encodeDocument(doc);
      expect(
        NoteContentCodec.isBlankNote(title: '', contentJson: encoded),
        isFalse,
      );
    });

    test('tryParseEmbeddable reads nested custom payload', () {
      final table = NoteonTableData.empty(rows: 1, columns: 1)
          .copyWithCell(0, 0, 'Cell');
      final custom = BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table));
      final parsed = NoteonTableBlockEmbed.tryParseEmbeddable(custom);
      expect(parsed, isNotNull);
      expect(parsed!.cells[0][0], 'Cell');
    });

    test('delta json shape uses custom wrapper', () {
      final table = NoteonTableData.empty(rows: 1, columns: 1);
      final doc = Document()
        ..insert(
          0,
          BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
        );
      final ops = jsonDecode(NoteContentCodec.encodeDocument(doc)) as List;
      final insert = (ops.first as Map)['insert'] as Map;
      expect(insert.containsKey('custom'), isTrue);
      expect('${insert['custom']}', contains('noteonTable'));
    });
  });
}
