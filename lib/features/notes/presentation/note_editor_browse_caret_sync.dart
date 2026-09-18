import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Coordinates Quill caret with user browsing so navigation feels document-like.
///
/// After a meaningful **user** browse (finger drag or pointer wheel), places a
/// collapsed caret in the visible band. Typing then continues where the user
/// looked — without fighting Quill's show-caret-on-edit, and without requiring
/// an extra tap solely to “unlock” the caret.
///
/// Programmatic scrolls (caret reveal) and ballistic flings are ignored as
/// browse gestures. Expanded selections are left alone so drag-select /
/// long-press keep working. Short notes that cannot meaningfully scroll do not
/// relocate the caret on overscroll bounce.
///
/// Wheel vs drag: each pointer-scroll tick ends with a [ScrollEndNotification]
/// (Flutter `pointerScroll` → didEndScroll). Drag browse is finalized on
/// ScrollEnd; wheel browse is accumulated across ticks and settled by a short
/// debounce so those per-tick ScrollEnds cannot clear distance early.
class NoteEditorBrowseCaretSync {
  NoteEditorBrowseCaretSync({
    required this.controller,
    required this.editorHostKey,
    required this.scrollController,
    this.minBrowseDistance = 36,
    this.viewportAnchor = 0.28,
  });

  final QuillController controller;
  final GlobalKey editorHostKey;
  final ScrollController scrollController;

  /// Ignore tiny scroll jitter / accidental nudges.
  final double minBrowseDistance;

  /// Vertical fraction of the editor viewport used as the edit target
  /// (0 = top, 1 = bottom). Slightly below the top keeps the caret out of
  /// the AppBar/keyboard transition zone.
  final double viewportAnchor;

  static const _wheelSettle = Duration(milliseconds: 140);

  bool _dragBrowsing = false;
  bool _wheelBrowsing = false;
  double _browseDistance = 0;
  bool _placingCaret = false;
  bool _disposed = false;
  Timer? _wheelSettleTimer;

  /// Forward from [NotificationListener] around the Quill editor.
  bool onScrollNotification(ScrollNotification notification) {
    if (_disposed || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      // Only active pointer-drags count here. Ballistic flings and
      // programmatic caret-reveal scrolls emit deltas without dragDetails.
      if (notification.dragDetails != null) {
        _armDragBrowse(notification.scrollDelta?.abs() ?? 0);
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      // Per-tick wheel ScrollEnds must not clear wheel accumulation — that is
      // owned by the settle timer. Only finalize an in-progress drag browse.
      if (!_dragBrowsing) {
        return false;
      }
      _wheelSettleTimer?.cancel();
      _wheelSettleTimer = null;
      final shouldPlace = _consumeBrowseIfReady(
        maxScrollExtent: notification.metrics.maxScrollExtent,
      );
      if (shouldPlace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_disposed) {
            return;
          }
          _placeCaretInVisibleBand();
        });
      }
    }

    return false;
  }

  /// Forward from a [Listener] for mouse-wheel / trackpad browsing.
  void onPointerScroll(PointerScrollEvent event) {
    if (_disposed) {
      return;
    }
    final dy = event.scrollDelta.dy.abs();
    if (dy <= 0) {
      return;
    }
    // Prefer an active finger-drag over interleaved wheel events.
    if (_dragBrowsing) {
      return;
    }
    _armWheelBrowse(dy);
    _wheelSettleTimer?.cancel();
    _wheelSettleTimer = Timer(_wheelSettle, () {
      _wheelSettleTimer = null;
      if (_disposed || !_wheelBrowsing) {
        return;
      }
      final extent = scrollController.hasClients
          ? scrollController.position.maxScrollExtent
          : 0.0;
      final shouldPlace = _consumeBrowseIfReady(maxScrollExtent: extent);
      if (shouldPlace) {
        _placeCaretInVisibleBand();
      }
    });
  }

  void dispose() {
    _disposed = true;
    _wheelSettleTimer?.cancel();
    _wheelSettleTimer = null;
  }

  void _armDragBrowse(double delta) {
    _wheelSettleTimer?.cancel();
    _wheelSettleTimer = null;
    _wheelBrowsing = false;
    _dragBrowsing = true;
    _browseDistance += delta;
  }

  void _armWheelBrowse(double delta) {
    _wheelBrowsing = true;
    _browseDistance += delta;
  }

  /// Returns whether caret placement should run, and always clears browse arm.
  bool _consumeBrowseIfReady({required double maxScrollExtent}) {
    final ready = (_dragBrowsing || _wheelBrowsing) &&
        _browseDistance >= minBrowseDistance &&
        maxScrollExtent >= minBrowseDistance;
    _dragBrowsing = false;
    _wheelBrowsing = false;
    _browseDistance = 0;
    return ready;
  }

  void _placeCaretInVisibleBand() {
    if (_placingCaret || _disposed || controller.readOnly) {
      return;
    }
    final selection = controller.selection;
    // Preserve drag / long-press selection ranges.
    if (selection.isValid && !selection.isCollapsed) {
      return;
    }

    final editor = _findRenderEditor();
    if (editor == null || !editor.hasSize) {
      return;
    }

    final size = editor.size;
    if (size.height <= 0 || size.width <= 0) {
      return;
    }

    final local = Offset(
      size.width / 2,
      (size.height * viewportAnchor).clamp(12.0, size.height - 12.0),
    );
    final global = editor.localToGlobal(local);
    final position = editor.getPositionForOffset(global);
    final docLen = controller.document.length;
    if (docLen <= 0) {
      return;
    }

    final offset = safeBrowseCaretOffset(controller.document, position.offset);
    if (selection.isValid && (selection.baseOffset - offset).abs() <= 1) {
      return;
    }

    _placingCaret = true;
    try {
      // Avoid forcing the IME open on browse-end; Quill clears this flag when
      // it honors skip, but not when the keyboard is already visible — so we
      // always restore false afterward.
      controller.skipRequestKeyboard = true;
      controller.updateSelection(
        TextSelection.collapsed(offset: offset),
        ChangeSource.local,
      );
    } finally {
      controller.skipRequestKeyboard = false;
      _placingCaret = false;
    }
  }

  RenderEditor? _findRenderEditor() {
    final ctx = editorHostKey.currentContext;
    if (ctx == null) {
      return null;
    }
    RenderEditor? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      final ro = element.renderObject;
      if (ro is RenderEditor) {
        found = ro;
        return;
      }
      element.visitChildren(visit);
    }

    ctx.visitChildElements(visit);
    return found;
  }
}

/// Prefers a text caret over landing on embed object-replacement characters.
///
/// Walks forward across consecutive embeds (e.g. drawing stacks) so typing
/// cannot replace an embed after browse placement.
@visibleForTesting
int safeBrowseCaretOffset(Document document, int raw) {
  final docLen = document.length;
  if (docLen <= 0) {
    return 0;
  }
  final max = math.max(0, docLen - 1);
  var offset = raw.clamp(0, max);
  // Bound iterations to document length to avoid pathological loops.
  for (var i = 0; i < docLen; i++) {
    final leaf = document.querySegmentLeafNode(offset).leaf;
    if (leaf is! Embed) {
      break;
    }
    offset = (leaf.documentOffset + leaf.length).clamp(0, max);
  }
  return offset;
}
