import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:noteon/features/notes/data/note_local_assist.dart';
import 'package:noteon/features/notes/data/note_pdf_exporter.dart';

void main() {
  group('NoteLocalAssist', () {
    test('tidyWhitespace collapses blank runs and trims', () {
      const input = 'Hello  world  \n\n\nNext line\t\n';
      expect(
        NoteLocalAssist.tidyWhitespace(input),
        'Hello world\n\nNext line',
      );
    });

    test('toBulletList prefixes lines without doubling existing markers', () {
      const input = 'One\n• Two\n3. Three\nFour';
      expect(
        NoteLocalAssist.toBulletList(input),
        '• One\n• Two\n3. Three\n• Four',
      );
    });

    test('emphasizeFirstLine inserts blank line after first content line', () {
      const input = 'Title\nBody line';
      expect(
        NoteLocalAssist.emphasizeFirstLine(input),
        'Title\n\nBody line',
      );
    });
  });

  group('NotePdfExporter', () {
    test('fromImageBytes produces a PDF header and trailer', () {
      final image = img.Image(width: 40, height: 30);
      img.fill(image, color: img.ColorRgb8(20, 40, 80));
      final png = Uint8List.fromList(img.encodePng(image));
      final pdf = NotePdfExporter.fromImageBytes(png);
      final asString = String.fromCharCodes(pdf.take(8));
      expect(asString.startsWith('%PDF-'), isTrue);
      expect(String.fromCharCodes(pdf).contains('%%EOF'), isTrue);
      expect(pdf.length, greaterThan(100));
    });
  });
}
