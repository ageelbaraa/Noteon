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
  }) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final body = NoteContentCodec.plainTextPreview(
      contentJson,
      maxLength: 4000,
    );
    final bytes = await renderNoteImage(
      title: title.trim().isEmpty ? l10n.appName : title.trim(),
      body: body.isEmpty ? l10n.shareEmptyNote : body,
      background: theme.colorScheme.surface,
      foreground: theme.colorScheme.onSurface,
      muted: theme.colorScheme.onSurfaceVariant,
      accent: theme.colorScheme.primary,
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
  }) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final body = NoteContentCodec.plainTextPreview(
      contentJson,
      maxLength: 8000,
    );
    final png = await renderNoteImage(
      title: title.trim().isEmpty ? l10n.appName : title.trim(),
      body: body.isEmpty ? l10n.shareEmptyNote : body,
      background: theme.colorScheme.surface,
      foreground: theme.colorScheme.onSurface,
      muted: theme.colorScheme.onSurfaceVariant,
      accent: theme.colorScheme.primary,
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

  /// Renders a simple note card as PNG (no Quill layout dependency).
  static Future<Uint8List> renderNoteImage({
    required String title,
    required String body,
    required Color background,
    required Color foreground,
    required Color muted,
    required Color accent,
    int width = 1080,
  }) async {
    const pad = 64.0;
    const titleStyle = TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w800,
      height: 1.2,
    );
    const bodyStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      height: 1.45,
    );

    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle.copyWith(color: foreground)),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: width - pad * 2);

    final bodyPainter = TextPainter(
      text: TextSpan(text: body, style: bodyStyle.copyWith(color: muted)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - pad * 2);

    final height = (pad * 2 + titlePainter.height + 28 + bodyPainter.height + 48)
        .clamp(640.0, 2400.0)
        .toDouble();

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
    bodyPainter.paint(
      canvas,
      Offset(pad, pad + titlePainter.height + 28),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
