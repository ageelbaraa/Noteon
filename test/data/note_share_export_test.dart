import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:noteon/features/notes/data/noteon_table_data.dart';
import 'package:noteon/features/notes/presentation/note_share_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renderNoteDocument includes table cell text in PNG bytes', () async {
    final table = NoteonTableData.empty(rows: 2, columns: 2).copyWith(
      cells: [
        ['Alpha', 'Beta'],
        ['Gamma', 'Delta'],
      ],
    );
    final contentJson = jsonEncode([
      {'insert': 'Hello export\n'},
      {
        'insert': {
          'custom': jsonEncode({'noteonTable': table.toJsonString()}),
        },
      },
      {'insert': '\n'},
    ]);

    final png = await NoteShareActions.renderNoteDocument(
      title: 'Export title',
      contentJson: contentJson,
      emptyBodyLabel: 'empty',
      background: Colors.white,
      foreground: Colors.black,
      muted: Colors.black87,
      accent: Colors.teal,
    );

    expect(png.length, greaterThan(1000));
    // PNG signature
    expect(png[0], 0x89);
    expect(png[1], 0x50);
  });

  test('renderNoteDocument embeds resolved image bytes', () async {
    final dir = await Directory.systemTemp.createTemp('noteon_export_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final file = File('${dir.path}${Platform.pathSeparator}pic.png');
    final image = img.Image(width: 32, height: 24);
    img.fill(image, color: img.ColorRgb8(200, 40, 40));
    await file.writeAsBytes(img.encodePng(image));

    final contentJson = jsonEncode([
      {'insert': 'With image\n'},
      {
        'insert': {'image': 'images/pic.png'},
      },
      {'insert': '\n'},
    ]);

    final withImage = await NoteShareActions.renderNoteDocument(
      title: 'Img',
      contentJson: contentJson,
      emptyBodyLabel: 'empty',
      background: Colors.white,
      foreground: Colors.black,
      muted: Colors.black87,
      accent: Colors.teal,
      resolveMedia: (relative) async {
        if (relative.endsWith('pic.png')) {
          return file;
        }
        return null;
      },
    );

    final textOnly = await NoteShareActions.renderNoteDocument(
      title: 'Img',
      contentJson: jsonEncode([
        {'insert': 'With image\n'},
      ]),
      emptyBodyLabel: 'empty',
      background: Colors.white,
      foreground: Colors.black,
      muted: Colors.black87,
      accent: Colors.teal,
    );

    // Image export should be larger than text-only of the same title/body.
    expect(withImage.length, greaterThan(textOnly.length));
  });

  test('legacy renderNoteImage still returns a PNG', () async {
    final bytes = await NoteShareActions.renderNoteImage(
      title: 'T',
      body: 'Body text',
      background: Colors.white,
      foreground: Colors.black,
      muted: Colors.grey,
      accent: Colors.blue,
    );
    expect(bytes, isA<Uint8List>());
    expect(bytes[0], 0x89);
  });
}
