import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/features/notes/data/note_content_codec.dart';

void main() {
  group('NoteContentCodec', () {
    test('round-trips delta json and builds previews', () {
      final empty = NoteContentCodec.emptyDeltaJson();
      expect(jsonDecode(empty), isA<List<dynamic>>());

      final doc = NoteContentCodec.documentFromJson(empty);
      doc.insert(0, 'Hello Noteon');
      final encoded = NoteContentCodec.encodeDocument(doc);

      expect(
        NoteContentCodec.plainTextPreview(encoded),
        contains('Hello Noteon'),
      );
      expect(
        NoteContentCodec.isBlankNote(title: '', contentJson: empty),
        isTrue,
      );
      expect(
        NoteContentCodec.isBlankNote(title: 'A', contentJson: empty),
        isFalse,
      );
    });

    test('handles invalid json safely', () {
      final preview = NoteContentCodec.plainTextPreview('not-json');
      expect(preview, isNot(contains('Exception')));
    });
  });
}
