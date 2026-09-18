import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Builds a minimal single-page PDF that embeds a JPEG image.
///
/// Used so Noteon can export notes as PDF without the `pdf` package
/// (incompatible with this app's `archive` constraint). All work is local.
abstract final class NotePdfExporter {
  /// Wraps [jpegBytes] in a letter-size PDF page, scaled to fit.
  static Uint8List fromJpeg({
    required Uint8List jpegBytes,
    int imageWidth = 0,
    int imageHeight = 0,
  }) {
    var width = imageWidth;
    var height = imageHeight;
    if (width <= 0 || height <= 0) {
      final decoded = img.decodeJpg(jpegBytes);
      if (decoded == null) {
        throw StateError('Invalid JPEG for PDF export');
      }
      width = decoded.width;
      height = decoded.height;
    }

    // Letter page in points
    const pageW = 612.0;
    const pageH = 792.0;
    const margin = 36.0;
    final maxW = pageW - margin * 2;
    final maxH = pageH - margin * 2;
    final scale = (maxW / width < maxH / height) ? maxW / width : maxH / height;
    final drawW = width * scale;
    final drawH = height * scale;
    final x = (pageW - drawW) / 2;
    final y = (pageH - drawH) / 2;

    final objects = <List<int>>[];

    void addObject(String header, [List<int>? stream]) {
      final buf = BytesBuilder(copy: false);
      buf.add(utf8.encode(header));
      if (stream != null) {
        buf.add(utf8.encode('stream\n'));
        buf.add(stream);
        buf.add(utf8.encode('\nendstream\n'));
      }
      buf.add(utf8.encode('endobj\n'));
      objects.add(buf.toBytes());
    }

    addObject('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\n');
    addObject('2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\n');
    addObject(
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageW $pageH] '
      '/Contents 4 0 R /Resources << /XObject << /Im0 5 0 R >> >> >>\n',
    );

    final content =
        'q\n$drawW 0 0 $drawH $x $y cm\n/Im0 Do\nQ\n';
    final contentBytes = utf8.encode(content);
    addObject(
      '4 0 obj\n<< /Length ${contentBytes.length} >>\n',
      contentBytes,
    );
    addObject(
      '5 0 obj\n<< /Type /XObject /Subtype /Image /Width $width /Height $height '
      '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode '
      '/Length ${jpegBytes.length} >>\n',
      jpegBytes,
    );

    final out = BytesBuilder(copy: false);
    out.add(utf8.encode('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n'));
    final offsets = <int>[0];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      out.add(objects[i]);
    }
    final xrefStart = out.length;
    out.add(utf8.encode('xref\n0 ${objects.length + 1}\n'));
    out.add(utf8.encode('0000000000 65535 f \n'));
    for (var i = 1; i <= objects.length; i++) {
      out.add(
        utf8.encode('${offsets[i].toString().padLeft(10, '0')} 00000 n \n'),
      );
    }
    out.add(
      utf8.encode(
        'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
        'startxref\n$xrefStart\n%%EOF\n',
      ),
    );
    return out.toBytes();
  }

  /// Converts an arbitrary image (PNG/JPEG/…) to JPEG then wraps as PDF.
  static Uint8List fromImageBytes(Uint8List imageBytes, {int quality = 88}) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw StateError('Could not decode image for PDF export');
    }
    final jpeg = Uint8List.fromList(
      img.encodeJpg(decoded, quality: quality),
    );
    return fromJpeg(
      jpegBytes: jpeg,
      imageWidth: decoded.width,
      imageHeight: decoded.height,
    );
  }
}
