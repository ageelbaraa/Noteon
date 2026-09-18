import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-device OCR. Never sends bytes off the device.
///
/// Supported on Android/iOS via ML Kit. Desktop builds report [isSupported] false.
abstract final class NoteOcrService {
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Recognizes text in an image file or raw bytes (written to a temp file).
  static Future<String> recognizeText({
    String? filePath,
    Uint8List? bytes,
  }) async {
    if (!isSupported) {
      throw const NoteOcrException(NoteOcrError.unsupportedPlatform);
    }
    if ((filePath == null || filePath.isEmpty) && bytes == null) {
      throw const NoteOcrException(NoteOcrError.missingImage);
    }

    File? temp;
    try {
      final path = filePath ??
          await () async {
            final dir = await getTemporaryDirectory();
            temp = File(
              p.join(
                dir.path,
                'noteon_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg',
              ),
            );
            await temp!.writeAsBytes(bytes!, flush: true);
            return temp!.path;
          }();

      final input = InputImage.fromFilePath(path);
      final recognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      try {
        final result = await recognizer.processImage(input);
        final text = result.text.trim();
        if (text.isEmpty) {
          throw const NoteOcrException(NoteOcrError.noTextFound);
        }
        return text;
      } finally {
        await recognizer.close();
      }
    } on NoteOcrException {
      rethrow;
    } catch (_) {
      throw const NoteOcrException(NoteOcrError.failed);
    } finally {
      try {
        await temp?.delete();
      } catch (_) {}
    }
  }
}

enum NoteOcrError {
  unsupportedPlatform,
  missingImage,
  noTextFound,
  failed,
}

class NoteOcrException implements Exception {
  const NoteOcrException(this.code);
  final NoteOcrError code;
}
