import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/features/notes/data/note_block_ops.dart';

void main() {
  test('insertBlockEmbed at EOF places caret on a line below the embed', () {
    final controller = QuillController.basic();
    NoteBlockOps.insertBlockEmbed(
      controller,
      BlockEmbed.image('sketches/demo.png'),
    );

    final plain = controller.document.toPlainText();
    // Embed + its line ending + following empty line terminator.
    expect(plain.length, greaterThanOrEqualTo(2));
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, 2);

    controller.replaceText(
      controller.selection.baseOffset,
      0,
      'Below',
      TextSelection.collapsed(offset: controller.selection.baseOffset + 5),
    );

    final ops = controller.document.toDelta().toList();
    expect(ops.first.data, isA<Map>());
    expect(
      ops.any((op) => op.data is String && (op.data as String).contains('Below')),
      isTrue,
    );
    // Typed text must not share the embed's insert object.
    expect(ops.first.data is Map, isTrue);
  });

  test('insertBlockEmbed after text keeps text above and caret below', () {
    final controller = QuillController(
      document: Document.fromJson([
        {'insert': 'Hello\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 5),
    );
    NoteBlockOps.insertBlockEmbed(
      controller,
      BlockEmbed.image('ink/preview.png'),
    );

    controller.replaceText(
      controller.selection.baseOffset,
      0,
      'World',
      TextSelection.collapsed(offset: controller.selection.baseOffset + 5),
    );

    final plain = controller.document.toPlainText();
    expect(plain.startsWith('Hello'), isTrue);
    expect(plain.contains('World'), isTrue);
    // Image object replacement char sits between Hello and World.
    final helloIdx = plain.indexOf('Hello');
    final worldIdx = plain.indexOf('World');
    expect(worldIdx, greaterThan(helloIdx));
  });

  test('insert mid-document moves caret to following paragraph', () {
    final controller = QuillController(
      document: Document.fromJson([
        {'insert': 'abc\ndef\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 3),
    );
    NoteBlockOps.insertBlockEmbed(
      controller,
      BlockEmbed.image('images/x.jpg'),
    );
    // After embed line: caret sits at the start of the following text ("def").
    expect(controller.selection.baseOffset, 6);
    controller.replaceText(
      controller.selection.baseOffset,
      0,
      'T',
      TextSelection.collapsed(offset: controller.selection.baseOffset + 1),
    );
    final plain = controller.document.toPlainText();
    expect(plain.contains('Tdef'), isTrue);
  });
}
