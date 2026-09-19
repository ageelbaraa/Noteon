import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_localizations.dart';
import '../data/note_content_codec.dart';
import '../data/note_pdf_exporter.dart';
import '../data/noteon_image_payload.dart';
import '../data/noteon_table_data.dart';

/// Share a note as plain text, image, or PDF (additive; no storage change).
abstract final class NoteShareActions {
  static String _composePlainText({
    required AppLocalizations l10n,
    required String title,
    required String contentJson,
  }) {
    final body = NoteContentCodec.plainTextPreview(
      contentJson,
      maxLength: 20000,
    );
    final buffer = StringBuffer();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) {
      buffer.writeln(trimmedTitle);
      buffer.writeln();
    }
    if (body.isNotEmpty) {
      buffer.write(body);
    } else if (trimmedTitle.isEmpty) {
      buffer.write(l10n.shareEmptyNote);
    }
    return buffer.toString();
  }

  static Future<void> shareAsText({
    required BuildContext context,
    required String title,
    required String contentJson,
  }) async {
    final l10n = AppLocalizations.of(context);
    final trimmedTitle = title.trim();
    await SharePlus.instance.share(
      ShareParams(
        text: _composePlainText(
          l10n: l10n,
          title: title,
          contentJson: contentJson,
        ),
        subject: trimmedTitle.isEmpty ? l10n.appName : trimmedTitle,
      ),
    );
  }

  static Future<void> shareAsImage({
    required BuildContext context,
    required String title,
    required String contentJson,
    Future<File?> Function(String relativePath)? resolveMedia,
  }) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bytes = await renderNoteDocument(
      title: title.trim().isEmpty ? l10n.appName : title.trim(),
      contentJson: contentJson,
      emptyBodyLabel: l10n.shareEmptyNote,
      background: theme.colorScheme.surface,
      foreground: theme.colorScheme.onSurface,
      muted: theme.colorScheme.onSurfaceVariant,
      accent: theme.colorScheme.primary,
      resolveMedia: resolveMedia,
    );

    final dir = await getTemporaryDirectory();
    final filePath = p.join(
      dir.path,
      'noteon_share_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await File(filePath).writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'image/png')],
        subject: title.trim().isEmpty ? l10n.appName : title.trim(),
      ),
    );
  }

  static Future<void> shareAsPdf({
    required BuildContext context,
    required String title,
    required String contentJson,
    Future<File?> Function(String relativePath)? resolveMedia,
  }) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final png = await renderNoteDocument(
      title: title.trim().isEmpty ? l10n.appName : title.trim(),
      contentJson: contentJson,
      emptyBodyLabel: l10n.shareEmptyNote,
      background: theme.colorScheme.surface,
      foreground: theme.colorScheme.onSurface,
      muted: theme.colorScheme.onSurfaceVariant,
      accent: theme.colorScheme.primary,
      resolveMedia: resolveMedia,
    );
    final pdfBytes = NotePdfExporter.fromImageBytes(png);

    final dir = await getTemporaryDirectory();
    var safeName = (title.trim().isEmpty ? 'note' : title.trim())
        .replaceAll(RegExp(r'[^\w\-]+'), '_');
    if (safeName.length > 40) {
      safeName = safeName.substring(0, 40);
    }
    final filePath = p.join(
      dir.path,
      'noteon_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await File(filePath).writeAsBytes(pdfBytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'application/pdf')],
        subject: title.trim().isEmpty ? l10n.appName : title.trim(),
      ),
    );
  }

  /// Renders title + Quill delta body (text, images, tables) as PNG.
  static Future<Uint8List> renderNoteDocument({
    required String title,
    required String contentJson,
    required String emptyBodyLabel,
    required Color background,
    required Color foreground,
    required Color muted,
    required Color accent,
    Future<File?> Function(String relativePath)? resolveMedia,
    int width = 1080,
  }) async {
    const pad = 64.0;
    final titleStyle = TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: foreground,
    );
    final bodyStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: muted,
    );
    final tableStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.35,
      color: foreground,
    );

    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: width - pad * 2);

    final blocks = await _buildExportBlocks(
      contentJson: contentJson,
      emptyBodyLabel: emptyBodyLabel,
      resolveMedia: resolveMedia,
      maxImageWidth: (width - pad * 2).round(),
    );

    final layout = <_LaidOutBlock>[];
    var cursorY = pad + titlePainter.height + 28;
    for (final block in blocks) {
      switch (block) {
        case _TextExportBlock(:final text):
          final painter = TextPainter(
            text: TextSpan(text: text, style: bodyStyle),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: width - pad * 2);
          layout.add(_LaidOutBlock(top: cursorY, painter: painter));
          cursorY += painter.height + 18;
        case _TableExportBlock(:final lines):
          final painter = TextPainter(
            text: TextSpan(text: lines.join('\n'), style: tableStyle),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: width - pad * 2);
          layout.add(_LaidOutBlock(top: cursorY, painter: painter));
          cursorY += painter.height + 22;
        case _ImageExportBlock(:final bytes, :final drawWidth, :final drawHeight):
          layout.add(
            _LaidOutBlock(
              top: cursorY,
              imageBytes: bytes,
              imageWidth: drawWidth,
              imageHeight: drawHeight,
            ),
          );
          cursorY += drawHeight + 22;
      }
    }

    final height = (cursorY + pad).clamp(640.0, 12000.0).toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, width.toDouble(), height);
    canvas.drawRect(rect, Paint()..color = background);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(32, 32, width - 64.0, height - 64.0),
        const Radius.circular(28),
      ),
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    titlePainter.paint(canvas, const Offset(pad, pad));
    for (final item in layout) {
      if (item.top + 8 > height - pad) {
        break;
      }
      final painter = item.painter;
      if (painter != null) {
        painter.paint(canvas, Offset(pad, item.top));
        continue;
      }
      final bytes = item.imageBytes;
      if (bytes == null) {
        continue;
      }
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: item.imageWidth.round().clamp(1, 4096),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final dst = Rect.fromLTWH(
        pad,
        item.top,
        item.imageWidth,
        item.imageHeight,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
      image.dispose();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Legacy plain-text card renderer (kept for tests / callers).
  static Future<Uint8List> renderNoteImage({
    required String title,
    required String body,
    required Color background,
    required Color foreground,
    required Color muted,
    required Color accent,
    int width = 1080,
  }) {
    return renderNoteDocument(
      title: title,
      contentJson: jsonEncode([
        {'insert': '$body\n'},
      ]),
      emptyBodyLabel: body,
      background: background,
      foreground: foreground,
      muted: muted,
      accent: accent,
      width: width,
    );
  }

  static Future<List<_ExportBlock>> _buildExportBlocks({
    required String contentJson,
    required String emptyBodyLabel,
    required Future<File?> Function(String relativePath)? resolveMedia,
    required int maxImageWidth,
  }) async {
    final blocks = <_ExportBlock>[];
    final textBuf = StringBuffer();

    void flushText() {
      final text = textBuf.toString().replaceAll('\uFFFC', '').trimRight();
      textBuf.clear();
      if (text.trim().isNotEmpty) {
        blocks.add(_TextExportBlock(text.trimRight()));
      }
    }

    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! List) {
        blocks.add(_TextExportBlock(emptyBodyLabel));
        return blocks;
      }

      for (final op in decoded) {
        if (op is! Map) {
          continue;
        }
        final insert = op['insert'];
        if (insert is String) {
          textBuf.write(insert);
          continue;
        }
        if (insert is! Map) {
          continue;
        }

        flushText();

        if (insert.containsKey('image')) {
          final path = NoteonImagePayload.decode(insert['image']).path;
          final imageBlock = await _imageBlockForPath(
            path: path,
            resolveMedia: resolveMedia,
            maxImageWidth: maxImageWidth,
          );
          if (imageBlock != null) {
            blocks.add(imageBlock);
          } else {
            blocks.add(const _TextExportBlock('[Image]'));
          }
          continue;
        }

        final table = _tableFromInsert(insert);
        if (table != null) {
          blocks.add(_TableExportBlock(_tableLines(table)));
          continue;
        }

        if (insert.containsKey('noteonInk') ||
            (insert['custom'] is String &&
                (insert['custom'] as String).contains('noteonInk'))) {
          blocks.add(const _TextExportBlock('[Drawing]'));
          continue;
        }
        if (insert.containsKey('noteonPdf') ||
            (insert['custom'] is String &&
                (insert['custom'] as String).contains('noteonPdf'))) {
          blocks.add(const _TextExportBlock('[PDF]'));
          continue;
        }
        if (insert.containsKey('noteonAudio') ||
            (insert['custom'] is String &&
                (insert['custom'] as String).contains('noteonAudio'))) {
          blocks.add(const _TextExportBlock('[Audio]'));
          continue;
        }
      }
      flushText();
    } catch (_) {
      // Fall through to empty handling.
    }

    if (blocks.isEmpty) {
      blocks.add(_TextExportBlock(emptyBodyLabel));
    }
    return blocks;
  }

  static NoteonTableData? _tableFromInsert(Map<dynamic, dynamic> insert) {
    try {
      if (insert['noteonTable'] is String) {
        return NoteonTableData.fromJsonString(insert['noteonTable'] as String);
      }
      final custom = insert['custom'];
      if (custom is String && custom.contains('noteonTable')) {
        final nested = jsonDecode(custom);
        if (nested is Map && nested['noteonTable'] is String) {
          return NoteonTableData.fromJsonString(
            nested['noteonTable'] as String,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static List<String> _tableLines(NoteonTableData table) {
    final lines = <String>[];
    final title = table.title.trim();
    if (title.isNotEmpty) {
      lines.add(title);
    }
    for (final row in table.cells) {
      final cells = [
        for (final cell in row) NoteonTableData.sanitizeCellText(cell).trim(),
      ];
      lines.add('| ${cells.join(' | ')} |');
    }
    return lines;
  }

  static Future<_ImageExportBlock?> _imageBlockForPath({
    required String path,
    required Future<File?> Function(String relativePath)? resolveMedia,
    required int maxImageWidth,
  }) async {
    if (path.isEmpty || resolveMedia == null) {
      return null;
    }
    try {
      final file = await resolveMedia(path);
      if (file == null || !await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final srcW = image.width.toDouble();
      final srcH = image.height.toDouble();
      image.dispose();
      if (srcW <= 0 || srcH <= 0) {
        return null;
      }
      final scale = srcW > maxImageWidth ? maxImageWidth / srcW : 1.0;
      return _ImageExportBlock(
        bytes: bytes,
        drawWidth: srcW * scale,
        drawHeight: srcH * scale,
      );
    } catch (_) {
      return null;
    }
  }
}

sealed class _ExportBlock {
  const _ExportBlock();
}

class _TextExportBlock extends _ExportBlock {
  const _TextExportBlock(this.text);
  final String text;
}

class _TableExportBlock extends _ExportBlock {
  const _TableExportBlock(this.lines);
  final List<String> lines;
}

class _ImageExportBlock extends _ExportBlock {
  const _ImageExportBlock({
    required this.bytes,
    required this.drawWidth,
    required this.drawHeight,
  });
  final Uint8List bytes;
  final double drawWidth;
  final double drawHeight;
}

class _LaidOutBlock {
  _LaidOutBlock({
    required this.top,
    this.painter,
    this.imageBytes,
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  final double top;
  final TextPainter? painter;
  final Uint8List? imageBytes;
  final double imageWidth;
  final double imageHeight;
}
