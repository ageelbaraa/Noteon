import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

import 'noteon_audio_payload.dart';
import 'noteon_image_payload.dart';
import 'noteon_ink_payload.dart';
import 'noteon_pdf_payload.dart';

/// Kind of a logical note element derived from the Quill Delta.
enum NoteBlockKind { text, image, table, audio, ink, pdf }

/// One ordered element in a note (text run, image embed, or table embed).
class NoteBlock {
  const NoteBlock({
    required this.kind,
    required this.start,
    required this.length,
    this.tableId,
    this.imagePath,
    this.audioPath,
    this.inkId,
    this.inkPreviewPath,
    this.pdfId,
    this.displayWidth,
  });

  final NoteBlockKind kind;

  /// Document offset of the first character/embed of this block.
  final int start;

  /// Length in Quill document units (embed == 1).
  final int length;

  /// Stable table id when [kind] is [NoteBlockKind.table].
  final String? tableId;

  /// Relative media path when [kind] is [NoteBlockKind.image].
  final String? imagePath;

  /// Relative media path when [kind] is [NoteBlockKind.audio].
  final String? audioPath;

  /// Stable ink id when [kind] is [NoteBlockKind.ink].
  final String? inkId;

  /// Preview PNG path when [kind] is [NoteBlockKind.ink].
  final String? inkPreviewPath;

  /// Stable PDF id when [kind] is [NoteBlockKind.pdf].
  final String? pdfId;

  /// Optional display width (px) from the image/ink payload.
  final double? displayWidth;

  int get end => start + length;

  bool get isEmbed =>
      kind == NoteBlockKind.image ||
      kind == NoteBlockKind.table ||
      kind == NoteBlockKind.audio ||
      kind == NoteBlockKind.ink ||
      kind == NoteBlockKind.pdf;
}

/// Selection of a single [NoteBlock] inside the note editor.
class NoteBlockSelection {
  const NoteBlockSelection({
    required this.blockIndex,
    required this.block,
  });

  final int blockIndex;
  final NoteBlock block;
}

/// Parses Quill documents into ordered [NoteBlock]s without changing storage.
abstract final class NoteBlockModel {
  /// Lists contentful blocks: images, tables, and non-whitespace text runs
  /// between embeds. Whitespace-only separators between embeds are skipped.
  static List<NoteBlock> listBlocks(Document document) {
    final blocks = <NoteBlock>[];
    var offset = 0;
    var textStart = -1;
    final textBuf = StringBuffer();

    void flushText() {
      if (textStart < 0) {
        return;
      }
      final raw = textBuf.toString();
      final contentful = raw.replaceAll(RegExp(r'[\s\uFFFC]'), '').isNotEmpty;
      if (contentful) {
        blocks.add(
          NoteBlock(
            kind: NoteBlockKind.text,
            start: textStart,
            length: raw.length,
          ),
        );
      }
      textStart = -1;
      textBuf.clear();
    }

    for (final op in document.toDelta().toList()) {
      final data = op.data;
      final len = op.length ?? 0;
      if (data is String) {
        if (textStart < 0) {
          textStart = offset;
        }
        textBuf.write(data);
        offset += len;
        continue;
      }

      if (data is Map) {
        final image = _image(data);
        if (image != null) {
          flushText();
          blocks.add(
            NoteBlock(
              kind: NoteBlockKind.image,
              start: offset,
              length: 1,
              imagePath: image.path,
              displayWidth: image.displayWidth,
            ),
          );
          offset += 1;
          continue;
        }

        final tableId = _tableId(data);
        if (tableId != null) {
          flushText();
          blocks.add(
            NoteBlock(
              kind: NoteBlockKind.table,
              start: offset,
              length: 1,
              tableId: tableId,
            ),
          );
          offset += 1;
          continue;
        }

        final audioPath = _audioPath(data);
        if (audioPath != null) {
          flushText();
          blocks.add(
            NoteBlock(
              kind: NoteBlockKind.audio,
              start: offset,
              length: 1,
              audioPath: audioPath,
            ),
          );
          offset += 1;
          continue;
        }

        final ink = _ink(data);
        if (ink != null) {
          flushText();
          blocks.add(
            NoteBlock(
              kind: NoteBlockKind.ink,
              start: offset,
              length: 1,
              inkId: ink.id,
              inkPreviewPath: ink.previewPath,
              displayWidth: ink.displayWidth,
            ),
          );
          offset += 1;
          continue;
        }

        final pdf = _pdf(data);
        if (pdf != null) {
          flushText();
          blocks.add(
            NoteBlock(
              kind: NoteBlockKind.pdf,
              start: offset,
              length: 1,
              pdfId: pdf.id,
              displayWidth: pdf.displayWidth,
            ),
          );
          offset += 1;
          continue;
        }
      }

      flushText();
      offset += len;
    }

    flushText();
    return blocks;
  }

  static NoteBlock? blockAtOffset(Document document, int offset) {
    final blocks = listBlocks(document);
    for (final block in blocks) {
      if (offset >= block.start && offset < block.end) {
        return block;
      }
      if (block.kind == NoteBlockKind.text &&
          offset == block.end &&
          offset > block.start) {
        return block;
      }
    }
    return null;
  }

  static ({String path, double? displayWidth})? _image(
    Map<dynamic, dynamic> data,
  ) {
    final raw = data[BlockEmbed.imageType];
    if (raw == null) {
      return null;
    }
    final decoded = NoteonImagePayload.decode(raw);
    if (decoded.path.isEmpty) {
      return null;
    }
    return decoded;
  }

  static String? _tableId(Map<dynamic, dynamic> data) {
    final custom = data[BlockEmbed.customType];
    if (custom is! String || !custom.contains('noteonTable')) {
      return null;
    }
    try {
      final nested = jsonDecode(custom);
      if (nested is! Map) {
        return null;
      }
      final tableRaw = nested['noteonTable'];
      if (tableRaw is! String) {
        return null;
      }
      final decoded = jsonDecode(tableRaw);
      if (decoded is! Map) {
        return null;
      }
      final id = decoded['id'];
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  static String? _audioPath(Map<dynamic, dynamic> data) {
    if (data['noteonAudio'] is String) {
      final path = NoteonAudioPayload.decode(data['noteonAudio']).path;
      return path.isEmpty ? null : path;
    }
    final custom = data[BlockEmbed.customType];
    if (custom is! String || !custom.contains('noteonAudio')) {
      return null;
    }
    try {
      final nested = jsonDecode(custom);
      if (nested is! Map) {
        return null;
      }
      final raw = nested['noteonAudio'];
      if (raw is! String) {
        return null;
      }
      final path = NoteonAudioPayload.decode(raw).path;
      return path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }

  static NoteonInkData? _ink(Map<dynamic, dynamic> data) {
    if (data['noteonInk'] is String) {
      final decoded = NoteonInkPayload.decode(data['noteonInk']);
      return decoded.isEmpty ? null : decoded;
    }
    final custom = data[BlockEmbed.customType];
    if (custom is! String || !custom.contains('noteonInk')) {
      return null;
    }
    try {
      final nested = jsonDecode(custom);
      if (nested is! Map) {
        return null;
      }
      final raw = nested['noteonInk'];
      if (raw is! String) {
        return null;
      }
      final decoded = NoteonInkPayload.decode(raw);
      return decoded.isEmpty ? null : decoded;
    } catch (_) {
      return null;
    }
  }

  static NoteonPdfData? _pdf(Map<dynamic, dynamic> data) {
    if (data['noteonPdf'] is String) {
      final decoded = NoteonPdfPayload.decode(data['noteonPdf']);
      return decoded.isEmpty ? null : decoded;
    }
    final custom = data[BlockEmbed.customType];
    if (custom is! String || !custom.contains('noteonPdf')) {
      return null;
    }
    try {
      final nested = jsonDecode(custom);
      if (nested is! Map) {
        return null;
      }
      final raw = nested['noteonPdf'];
      if (raw is! String) {
        return null;
      }
      final decoded = NoteonPdfPayload.decode(raw);
      return decoded.isEmpty ? null : decoded;
    } catch (_) {
      return null;
    }
  }
}
