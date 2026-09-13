import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../../features/notes/data/media_ref.dart';

/// Copies note media into the private app documents tree (`noteon_media`).
///
/// UI code should only deal with [MediaRef.relativePath] values — never raw
/// gallery/camera paths.
class MediaStorageService {
  MediaStorageService({Uuid? uuid, Directory? rootOverride})
      : _uuid = uuid ?? const Uuid(),
        _rootOverride = rootOverride;

  final Uuid _uuid;
  final Directory? _rootOverride;

  static const String imagesSubdirectory = 'images';
  static const String sketchesSubdirectory = 'sketches';
  static const String lockedSubdirectory = 'locked';

  /// Longest edge kept when resizing large photos.
  static const int maxEdge = 1600;

  /// JPEG quality after lightweight compression.
  static const int jpegQuality = 85;

  Future<Directory> mediaRoot() async {
    final override = _rootOverride;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }

    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, AppConstants.mediaDirectoryName));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  /// Absolute filesystem path for a stored relative media path.
  Future<String> absolutePathFor(String relativePath) async {
    final root = await mediaRoot();
    final normalized = relativePath.replaceAll('\\', '/');
    return p.joinAll([root.path, ...normalized.split('/')]);
  }

  Future<File?> fileFor(String relativePath) async {
    final absolute = await absolutePathFor(relativePath);
    final file = File(absolute);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Imports a picked image into private storage and returns a [MediaRef].
  Future<MediaRef> importImageFile(
    File source, {
    String kind = 'image',
  }) async {
    final raw = await source.readAsBytes();
    final encoded = _encodeForStorage(raw);

    final subdirectory =
        kind == 'sketch' ? sketchesSubdirectory : imagesSubdirectory;
    final fileName = '${_uuid.v4()}.jpg';
    final relativePath = '$subdirectory/$fileName';

    final destination = File(await absolutePathFor(relativePath));
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(encoded, flush: true);

    return MediaRef()
      ..relativePath = relativePath
      ..kind = kind
      ..createdAt = DateTime.now();
  }

  /// Saves a PNG sketch under `sketches/` without JPEG recompression.
  Future<MediaRef> importSketchPng(Uint8List pngBytes) async {
    final fileName = '${_uuid.v4()}.png';
    final relativePath = '$sketchesSubdirectory/$fileName';
    final destination = File(await absolutePathFor(relativePath));
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(pngBytes, flush: true);

    return MediaRef()
      ..relativePath = relativePath
      ..kind = 'sketch'
      ..createdAt = DateTime.now();
  }

  /// Deletes a single media file if it exists. Missing files are ignored.
  Future<void> deleteRelativePath(String relativePath) async {
    if (relativePath.trim().isEmpty) {
      return;
    }
    try {
      final file = File(await absolutePathFor(relativePath));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup; missing/locked files should not break note flows.
    }
  }

  Future<void> deleteAll(Iterable<MediaRef> refs) async {
    for (final ref in refs) {
      await deleteRelativePath(ref.relativePath);
    }
  }

  /// Writes arbitrary bytes at a relative path under the media root.
  Future<void> writeBytesAtRelativePath(
    String relativePath,
    Uint8List bytes,
  ) async {
    final destination = File(await absolutePathFor(relativePath));
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes, flush: true);
  }

  /// Stores ciphertext for a locked note under `locked/{noteId}/`.
  Future<String> writeLockedCiphertext({
    required int noteId,
    required Uint8List ciphertextWithMac,
  }) async {
    final fileName = '${_uuid.v4()}.enc';
    final relativePath = '$lockedSubdirectory/$noteId/$fileName';
    await writeBytesAtRelativePath(relativePath, ciphertextWithMac);
    return relativePath;
  }

  Future<List<String>> listLockedMediaRelativePaths(int noteId) async {
    final dir = Directory(await absolutePathFor('$lockedSubdirectory/$noteId'));
    if (!await dir.exists()) {
      return const [];
    }
    final paths = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        paths.add('$lockedSubdirectory/$noteId/${p.basename(entity.path)}');
      }
    }
    return paths;
  }

  /// Removes all encrypted media files for a note (no password required).
  Future<void> deleteNoteLockedMedia(int noteId) async {
    try {
      final dir =
          Directory(await absolutePathFor('$lockedSubdirectory/$noteId'));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  /// Deletes every file under the media root (used by replace-import).
  Future<void> clearAllMedia() async {
    final root = await mediaRoot();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);
  }

  /// Reads bytes for a relative path, or null when missing.
  Future<Uint8List?> readBytesAtRelativePath(String relativePath) async {
    final file = await fileFor(relativePath);
    if (file == null) {
      return null;
    }
    return file.readAsBytes();
  }

  /// Removes files that are no longer referenced and builds the updated list.
  Future<List<MediaRef>> reconcile({
    required List<MediaRef> previous,
    required Iterable<String> liveRelativePaths,
  }) async {
    final live = liveRelativePaths
        .map((path) => path.replaceAll('\\', '/'))
        .where((path) => path.isNotEmpty)
        .toSet();
    final previousByPath = {
      for (final ref in previous) ref.relativePath.replaceAll('\\', '/'): ref,
    };

    for (final entry in previousByPath.entries) {
      if (!live.contains(entry.key)) {
        await deleteRelativePath(entry.key);
      }
    }

    return live.map((path) {
      final existing = previousByPath[path];
      if (existing != null) {
        return existing;
      }
      return MediaRef()
        ..relativePath = path
        ..kind = path.startsWith('$sketchesSubdirectory/') ? 'sketch' : 'image'
        ..createdAt = DateTime.now();
    }).toList();
  }

  Uint8List _encodeForStorage(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      // Keep original bytes when the decoder cannot handle the format.
      return raw;
    }

    var image = decoded;
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > maxEdge) {
      if (image.width >= image.height) {
        image = img.copyResize(image, width: maxEdge);
      } else {
        image = img.copyResize(image, height: maxEdge);
      }
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
  }
}
