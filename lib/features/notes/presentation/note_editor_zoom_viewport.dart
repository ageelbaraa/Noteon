import 'package:flutter/material.dart';

/// Builds a Samsung Notes–style zoom matrix: scale around a scene point so
/// that [focalViewport] stays on [focalScene].
///
/// Always `T(focal) * S(scale) * T(-scene)` — never stacked scales on a
/// translated matrix, which made pinch-in irreversible.
Matrix4 noteEditorZoomMatrix({
  required double scale,
  required Offset focalViewport,
  required Offset focalScene,
}) {
  return Matrix4.identity()
    ..translateByDouble(focalViewport.dx, focalViewport.dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(-focalScene.dx, -focalScene.dy, 0, 1);
}

double noteEditorZoomScale({
  required double startScale,
  required double startSpan,
  required double span,
  required double minScale,
  required double maxScale,
}) {
  final safeStartSpan = startSpan < 1 ? 1.0 : startSpan;
  return (startScale * (span / safeStartSpan)).clamp(minScale, maxScale);
}

/// Samsung Notes–style pinch zoom for the note body.
///
/// Two-finger pinch zooms around the finger focal point; two-finger drag pans
/// while zoomed. 1× is only the starting size — pinch-in shrinks and pinch-out
/// enlarges within [minScale]–[maxScale]. Uses a [Listener] so one-finger
/// scroll/select/edit keep working.
class NoteEditorZoomViewport extends StatefulWidget {
  const NoteEditorZoomViewport({
    super.key,
    required this.child,
    this.minScale = 0.25,
    this.maxScale = 8,
  });

  final Widget child;
  final double minScale;
  final double maxScale;

  @override
  State<NoteEditorZoomViewport> createState() => _NoteEditorZoomViewportState();
}

class _NoteEditorZoomViewportState extends State<NoteEditorZoomViewport> {
  final _transform = TransformationController();

  /// Active pointer positions in this viewport's local coordinates.
  final Map<int, Offset> _pointers = {};

  double _gestureStartScale = 1;
  double _gestureStartSpan = 1;
  Offset? _referenceFocalScene;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Listener(
        // Must hit the full viewport, not only the scaled child. Otherwise
        // pinch-in shrinks the hit target and the gesture is cancelled —
        // the reason zoom-out appeared broken from 1× after zooming in.
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: ListenableBuilder(
          listenable: _transform,
          builder: (context, _) {
            return Transform(
              transform: _transform.value,
              // Medium filtering while editing at 1× re-rasters embeds on every
              // text frame and reads as flicker. Use none at identity; medium only
              // when actually zoomed.
              filterQuality: _transform.value.getMaxScaleOnAxis() > 1.02
                  ? FilterQuality.medium
                  : FilterQuality.none,
              child: SizedBox.expand(child: widget.child),
            );
          },
        ),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      _beginTwoFingerGesture();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) {
      return;
    }
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length != 2 || _referenceFocalScene == null) {
      return;
    }
    _updateTwoFingerGesture();
  }

  void _onPointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);

    if (_pointers.length == 2) {
      _beginTwoFingerGesture();
      return;
    }

    _referenceFocalScene = null;

    if (_pointers.isEmpty) {
      _normalizeNearDefaultScale();
    }
  }

  void _beginTwoFingerGesture() {
    _gestureStartScale = _transform.value.getMaxScaleOnAxis();
    _gestureStartSpan = _fingerSpan();
    _referenceFocalScene = _toScene(_transform.value, _focalPoint());
  }

  void _updateTwoFingerGesture() {
    final reference = _referenceFocalScene;
    if (reference == null) {
      return;
    }

    final focal = _focalPoint();
    final scale = noteEditorZoomScale(
      startScale: _gestureStartScale,
      startSpan: _gestureStartSpan,
      span: _fingerSpan(),
      minScale: widget.minScale,
      maxScale: widget.maxScale,
    );

    _transform.value = noteEditorZoomMatrix(
      scale: scale,
      focalViewport: focal,
      focalScene: reference,
    );
  }

  /// Settle on a clean identity only when the user lands near the default 1×.
  /// Do not snap a deliberately zoomed-out or zoomed-in scale.
  void _normalizeNearDefaultScale() {
    final scale = _transform.value.getMaxScaleOnAxis();
    if ((scale - 1.0).abs() <= 0.04) {
      _transform.value = Matrix4.identity();
    }
  }

  Offset _focalPoint() {
    final points = _pointers.values.toList(growable: false);
    return (points[0] + points[1]) / 2;
  }

  double _fingerSpan() {
    final points = _pointers.values.toList(growable: false);
    return (points[0] - points[1]).distance.clamp(1.0, double.infinity);
  }

  Offset _toScene(Matrix4 matrix, Offset viewportPoint) {
    final inverse = Matrix4.tryInvert(Matrix4.copy(matrix));
    if (inverse == null) {
      return viewportPoint;
    }
    return MatrixUtils.transformPoint(inverse, viewportPoint);
  }
}
