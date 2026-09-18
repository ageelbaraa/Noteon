import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import 'note_block_model.dart';
import 'noteon_image_payload.dart';
import 'noteon_ink_payload.dart';

/// In-document block operations on the Quill Delta (single source of truth).
///
/// All mutations go through [QuillController.replaceText] so Quill undo/redo
/// continues to work. Never duplicates embeds.
abstract final class NoteBlockOps {
  /// Deletes [block] from the document. Returns `true` when something changed.
  static bool deleteBlock(QuillController controller, NoteBlock block) {
    final docLen = controller.document.length;
    if (block.start < 0 || block.start >= docLen || block.length <= 0) {
      return false;
    }
    final len = block.length.clamp(1, docLen - block.start);
    controller.replaceText(
      block.start,
      len,
      '',
      TextSelection.collapsed(offset: block.start.clamp(0, docLen - 1)),
      ignoreFocus: true,
    );
    return true;
  }

  /// Moves the block at [fromIndex] so it lands at insert-before [toIndex].
  ///
  /// No-op when the move would not change order. Returns the new block index
  /// after the move, or `null` on failure.
  static int? moveBlock(
    QuillController controller, {
    required int fromIndex,
    required int toIndex,
  }) {
    final blocks = NoteBlockModel.listBlocks(controller.document);
    if (fromIndex < 0 || fromIndex >= blocks.length) {
      return null;
    }
    if (toIndex == fromIndex || toIndex == fromIndex + 1) {
      return fromIndex;
    }
    if (toIndex < 0 || toIndex > blocks.length) {
      return null;
    }

    final block = blocks[fromIndex];
    final slice = sliceDelta(controller.document, block.start, block.length);
    if (slice.isEmpty) {
      return null;
    }

    controller.replaceText(
      block.start,
      block.length,
      '',
      TextSelection.collapsed(offset: block.start),
      ignoreFocus: true,
    );

    final adjustedTo = toIndex > fromIndex ? toIndex - 1 : toIndex;
    final after = NoteBlockModel.listBlocks(controller.document);
    final insertAt = adjustedTo >= after.length
        ? _safeInsertEnd(controller.document)
        : after[adjustedTo].start;

    final payload = _insertPayload(slice);
    controller.replaceText(
      insertAt,
      0,
      payload,
      TextSelection.collapsed(offset: insertAt),
      ignoreFocus: true,
    );

    final moved = NoteBlockModel.listBlocks(controller.document);
    if (block.tableId != null) {
      for (var i = 0; i < moved.length; i++) {
        if (moved[i].tableId == block.tableId) {
          return i;
        }
      }
    }
    if (block.inkId != null) {
      for (var i = 0; i < moved.length; i++) {
        if (moved[i].inkId == block.inkId) {
          return i;
        }
      }
    }
    if (block.pdfId != null) {
      for (var i = 0; i < moved.length; i++) {
        if (moved[i].pdfId == block.pdfId) {
          return i;
        }
      }
    }
    if (block.kind == NoteBlockKind.image && block.imagePath != null) {
      for (var i = 0; i < moved.length; i++) {
        if (moved[i].kind == NoteBlockKind.image &&
            moved[i].imagePath == block.imagePath &&
            moved[i].start == insertAt) {
          return i;
        }
      }
      for (var i = 0; i < moved.length; i++) {
        if (moved[i].kind == NoteBlockKind.image &&
            moved[i].imagePath == block.imagePath) {
          return i;
        }
      }
    }
    if (moved.isEmpty) {
      return null;
    }
    if (adjustedTo >= moved.length) {
      return moved.length - 1;
    }
    return adjustedTo.clamp(0, moved.length - 1);
  }

  static bool moveBlockUp(QuillController controller, int blockIndex) {
    if (blockIndex <= 0) {
      return false;
    }
    return moveBlock(
          controller,
          fromIndex: blockIndex,
          toIndex: blockIndex - 1,
        ) !=
        null;
  }

  static bool moveBlockDown(QuillController controller, int blockIndex) {
    final blocks = NoteBlockModel.listBlocks(controller.document);
    if (blockIndex < 0 || blockIndex >= blocks.length - 1) {
      return false;
    }
    // Insert before the block currently two ahead (= after the next block).
    return moveBlock(
          controller,
          fromIndex: blockIndex,
          toIndex: blockIndex + 2,
        ) !=
        null;
  }

  /// Sets display width on an image embed without rewriting the file.
  static bool setImageDisplayWidth(
    QuillController controller, {
    required int imageOffset,
    required double width,
  }) {
    final block = _imageAt(controller, imageOffset);
    if (block == null || block.imagePath == null) {
      return false;
    }
    final clamped = width.clamp(80.0, 2000.0);
    controller.replaceText(
      imageOffset,
      1,
      NoteonImagePayload.embed(
        path: block.imagePath!,
        displayWidth: clamped,
      ),
      TextSelection.collapsed(offset: imageOffset + 1),
      ignoreFocus: true,
    );
    return true;
  }

  /// Replaces the image path at [imageOffset], preserving width when present.
  static bool replaceImage(
    QuillController controller, {
    required int imageOffset,
    required String newRelativePath,
  }) {
    final block = _imageAt(controller, imageOffset);
    if (block == null) {
      return false;
    }
    controller.replaceText(
      imageOffset,
      1,
      NoteonImagePayload.embed(
        path: newRelativePath,
        displayWidth: block.displayWidth,
      ),
      TextSelection.collapsed(offset: imageOffset + 1),
      ignoreFocus: true,
    );
    return true;
  }

  /// Updates display width on an ink embed without rewriting media files.
  static bool setInkDisplayWidth(
    QuillController controller, {
    required int inkOffset,
    required double width,
    required NoteonInkData data,
  }) {
    final clamped = width.clamp(80.0, 2000.0);
    controller.replaceText(
      inkOffset,
      1,
      BlockEmbed.custom(
        NoteonInkBlockEmbed.fromData(data.copyWith(displayWidth: clamped)),
      ),
      TextSelection.collapsed(offset: inkOffset + 1),
      ignoreFocus: true,
    );
    return true;
  }

  /// Replaces an ink embed payload at [inkOffset] (re-edit save).
  static bool replaceInk(
    QuillController controller, {
    required int inkOffset,
    required NoteonInkData data,
  }) {
    controller.replaceText(
      inkOffset,
      1,
      BlockEmbed.custom(NoteonInkBlockEmbed.fromData(data)),
      TextSelection.collapsed(offset: inkOffset + 1),
      ignoreFocus: true,
    );
    return true;
  }

  /// Inserts a block embed on its own line and places the caret on the line
  /// after it so typing continues below images/ink/pdf/audio/tables.
  ///
  /// At end-of-document the Quill terminator `\n` is the embed line's ending,
  /// not a following paragraph — an extra `\n` is required in that case.
  static void insertBlockEmbed(QuillController controller, Embeddable embed) {
    final document = controller.document;
    var index = controller.selection.isValid
        ? controller.selection.baseOffset
        : document.length - 1;
    index = index.clamp(0, document.length - 1);

    final itr = DeltaIterator(document.toDelta());
    final prev = index > 0 ? itr.skip(index) : null;
    final cur = itr.next();
    final textBefore =
        prev != null && prev.data is String ? prev.data as String : '';
    final textAfter = cur.data is String ? cur.data as String : '';
    final isNewlineBefore = prev == null || textBefore.endsWith('\n');
    final isNewlineAfter = textAfter.startsWith('\n');

    if (!isNewlineBefore) {
      controller.replaceText(
        index,
        0,
        '\n',
        TextSelection.collapsed(offset: index + 1),
      );
      index += 1;
    }

    controller.replaceText(
      index,
      0,
      embed,
      TextSelection.collapsed(offset: index + 1),
    );

    if (!isNewlineAfter) {
      controller.replaceText(
        index + 1,
        0,
        '\n',
        TextSelection.collapsed(offset: index + 2),
      );
      return;
    }

    // Terminator `\n` already follows the embed. At EOF that is the embed's
    // own line ending — insert a real following line and move the caret there.
    if (index + 2 >= controller.document.length) {
      controller.replaceText(
        index + 1,
        0,
        '\n',
        TextSelection.collapsed(offset: index + 2),
      );
    } else {
      controller.updateSelection(
        TextSelection.collapsed(offset: index + 2),
        ChangeSource.local,
      );
    }
  }

  static NoteBlock? _imageAt(QuillController controller, int imageOffset) {
    for (final b in NoteBlockModel.listBlocks(controller.document)) {
      if (b.kind == NoteBlockKind.image && b.start == imageOffset) {
        return b;
      }
    }
    return null;
  }

  /// Extracts insert ops covering `[start, start+length)` from [document].
  static Delta sliceDelta(Document document, int start, int length) {
    final out = Delta();
    if (length <= 0) {
      return out;
    }
    final itr = DeltaIterator(document.toDelta());
    itr.skip(start);
    var remaining = length;
    while (remaining > 0 && itr.hasNext) {
      final op = itr.next(remaining);
      if (!op.isInsert) {
        break;
      }
      out.push(op);
      remaining -= op.length ?? 0;
    }
    return out;
  }

  /// Prefer [Embeddable] for single-embed slices so Quill insert heuristics apply.
  static Object _insertPayload(Delta slice) {
    if (slice.length == 1) {
      final data = slice.first.data;
      if (data is Map) {
        return Embeddable.fromJson(Map<String, dynamic>.from(data));
      }
      if (data is String) {
        return data;
      }
    }
    return slice;
  }

  static int _safeInsertEnd(Document document) {
    final len = document.length;
    return len <= 1 ? 0 : len - 1;
  }
}
