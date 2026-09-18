import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/l10n/app_localizations.dart';
import 'package:noteon/features/notes/data/note_content_codec.dart';
import 'package:noteon/features/notes/data/noteon_table_data.dart';
import 'package:noteon/features/notes/presentation/noteon_table_embed.dart';

void main() {
  test('embed toPlainText is a single object-replacement char', () {
    final table = NoteonTableData.empty(rows: 2, columns: 2)
        .copyWithCell(0, 0, 'My text');
    final embed = Embed(
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
    );
    final unwrapped = Embed(
      CustomBlockEmbed.fromJsonString(embed.value.data as String),
    );
    final plain = const NoteonTableEmbedBuilder().toPlainText(unwrapped);
    expect(plain, Embed.kObjectReplacementCharacter);
    expect(plain.length, 1);
    expect(plain.contains('My text'), isFalse);
  });

  test('sanitizeCellText keeps strings and rejects structured values', () {
    expect(
      NoteonTableData.sanitizeCellText(
        'My text${Embed.kObjectReplacementCharacter}',
      ),
      'My text',
    );
    expect(NoteonTableData.sanitizeCellText({'nested': true}), '');
    expect(NoteonTableData.sanitizeCellText(null), '');
    expect(NoteonTableData.sanitizeCellText(12), '12');
  });

  test('legacy json with map cell stays a plain empty string', () {
    final table = NoteonTableData.fromJson({
      'id': 'x',
      'rows': 1,
      'columns': 1,
      'cells': [
        [
          {'nested': true},
        ],
      ],
    });
    expect(table.cells[0][0], '');
    expect(table.cells[0][0].toLowerCase().contains('object'), isFalse);
  });

  test('commit then encode/decode keeps cell text without FFFC leakage', () {
    final table = NoteonTableData.empty(rows: 2, columns: 2)
        .copyWithCell(0, 0, 'My text');
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
      const TextSelection.collapsed(offset: 1),
    );

    final offset = NoteonTableDocument.offsetOf(controller.document, table.id)!;
    final updated = table.copyWithCell(0, 0, 'My text edited');
    controller.replaceText(
      offset,
      1,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(updated)),
      TextSelection.collapsed(offset: offset),
      ignoreFocus: true,
    );

    final encoded = NoteContentCodec.encodeDocument(controller.document);
    expect(encoded.contains('My text edited'), isTrue);
    expect(encoded.contains('\uFFFC'), isFalse);

    final restored = NoteContentCodec.documentFromJson(encoded);
    NoteonTableData? found;
    for (final op in restored.toDelta().toList()) {
      final data = op.data;
      if (data is Map && data['custom'] is String) {
        found = NoteonTableBlockEmbed.tryParseEmbeddable(
          Embeddable.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    }
    expect(found, isNotNull);
    expect(found!.cells[0][0], 'My text edited');
  });

  testWidgets(
      'table embed has no nested TextFields; sheet edits one cell only',
      (tester) async {
    final editorFocus = FocusNode();
    addTearDown(editorFocus.dispose);

    final table = NoteonTableData.empty(rows: 2, columns: 2)
        .copyWithCell(0, 0, 'Alpha')
        .copyWithCell(0, 1, 'Beta');
    final controller = QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    addTearDown(controller.dispose);
    controller.replaceText(
      0,
      0,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
      const TextSelection.collapsed(offset: 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(
          body: QuillEditor.basic(
            controller: controller,
            focusNode: editorFocus,
            config: QuillEditorConfig(
              embedBuilders: [
                NoteonTableEmbedBuilder(editorFocusNode: editorFocus),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Display-only table: zero nested TextFields inside the note editor.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    // Exactly one TextField — in the modal sheet, not nested in Quill.
    expect(find.byType(TextField), findsOneWidget);
    expect(editorFocus.hasFocus, isFalse);

    await tester.enterText(find.byType(TextField), 'Alpha edited');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Alpha edited'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    NoteonTableData? stored;
    for (final op in controller.document.toDelta().toList()) {
      final data = op.data;
      if (data is Map && data['custom'] is String) {
        stored = NoteonTableBlockEmbed.tryParseEmbeddable(
          Embeddable.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    }
    expect(stored, isNotNull);
    expect(stored!.cells[0][0], 'Alpha edited');
    expect(stored.cells[0][1], 'Beta');
    expect(stored.cells[0][0].contains('obj'), isFalse);
    expect(stored.cells[0][0].contains('\uFFFC'), isFalse);
    expect(_countTableEmbeds(controller.document), 1);
  });
}

int _countTableEmbeds(Document doc) {
  var count = 0;
  for (final op in doc.toDelta().toList()) {
    final data = op.data;
    if (data is! Map) {
      continue;
    }
    final custom = data['custom'];
    if (custom is String && custom.contains('noteonTable')) {
      count++;
    }
  }
  return count;
}
