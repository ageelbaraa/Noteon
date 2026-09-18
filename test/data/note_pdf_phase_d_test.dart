import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/media/media_storage_service.dart';
import 'package:noteon/features/notes/data/note_block_model.dart';
import 'package:noteon/features/notes/data/note_content_codec.dart';
import 'package:noteon/features/notes/data/note_media_paths.dart';
import 'package:noteon/features/notes/data/noteon_pdf_annotations.dart';
import 'package:noteon/features/notes/data/noteon_pdf_payload.dart';

void main() {
  test('pdf payload round-trips paths and title', () {
    final raw = NoteonPdfPayload.encode(
      id: 'p1',
      pdfPath: 'pdfs/p1.pdf',
      annotationsPath: 'pdfs/p1.ann.json',
      title: 'Syllabus',
      displayWidth: 320,
    );
    final decoded = NoteonPdfPayload.decode(raw);
    expect(decoded.id, 'p1');
    expect(decoded.pdfPath, 'pdfs/p1.pdf');
    expect(decoded.annotationsPath, 'pdfs/p1.ann.json');
    expect(decoded.title, 'Syllabus');
    expect(decoded.mediaPaths, ['pdfs/p1.pdf', 'pdfs/p1.ann.json']);
  });

  test('annotations encode/decode strokes without mutating pdf concept', () {
    final ann = NoteonPdfAnnotations.empty().copyWithPage(0, [
      const NoteonPdfStroke(
        points: [Offset(0.1, 0.1), Offset(0.2, 0.2)],
        color: 0xFFE11D48,
        width: 0.01,
        tool: NoteonPdfTool.pen,
      ),
    ]);
    final roundTrip = NoteonPdfAnnotations.decode(ann.encode());
    expect(roundTrip.strokesForPage(0), hasLength(1));
    expect(roundTrip.strokesForPage(0).first.points.first.dx, 0.1);
    expect(roundTrip.strokesForPage(1), isEmpty);
  });

  test('NoteMediaPaths extracts pdf and annotation files', () {
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      BlockEmbed.custom(
        NoteonPdfBlockEmbed.fromData(
          const NoteonPdfData(
            id: 'doc',
            pdfPath: 'pdfs/doc.pdf',
            annotationsPath: 'pdfs/doc.ann.json',
            title: 'Doc',
          ),
        ),
      ),
      const TextSelection.collapsed(offset: 1),
    );
    final json = NoteContentCodec.encodeDocument(controller.document);
    expect(
      NoteMediaPaths.extractFromContentJson(json),
      ['pdfs/doc.pdf', 'pdfs/doc.ann.json'],
    );
    expect(NoteContentCodec.isBlankNote(title: '', contentJson: json), isFalse);
  });

  test('listBlocks includes pdf; kindForRelativePath recognizes pdfs/', () {
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      BlockEmbed.custom(
        NoteonPdfBlockEmbed.fromData(
          const NoteonPdfData(
            id: 'z',
            pdfPath: 'pdfs/z.pdf',
            annotationsPath: 'pdfs/z.ann.json',
          ),
        ),
      ),
      const TextSelection.collapsed(offset: 1),
    );
    final blocks = NoteBlockModel.listBlocks(controller.document);
    expect(blocks.single.kind, NoteBlockKind.pdf);
    expect(blocks.single.pdfId, 'z');
    expect(MediaStorageService.kindForRelativePath('pdfs/z.pdf'), 'pdf');
  });
}
