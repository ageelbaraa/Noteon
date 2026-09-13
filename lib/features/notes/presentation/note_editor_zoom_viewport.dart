import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Pinch-to-zoom + pan canvas around the note body (Samsung Notes–style).
///
/// At 100% scale, pan is disabled so normal editor scrolling/selection works.
/// When zoomed in, the user can pan to focus a region while the editor still
/// scrolls internally for long notes.
class NoteEditorZoomViewport extends StatefulWidget {
  const NoteEditorZoomViewport({
    super.key,
    required this.child,
    this.minScale = 1,
    this.maxScale = 3.5,
  });

  final Widget child;
  final double minScale;
  final double maxScale;

  @override
  State<NoteEditorZoomViewport> createState() => NoteEditorZoomViewportState();
}

class NoteEditorZoomViewportState extends State<NoteEditorZoomViewport> {
  final _transform = TransformationController();
  final _scale = ValueNotifier<double>(1);

  /// Whether pan is enabled; only toggles when crossing the zoom threshold so
  /// pinch gestures do not rebuild the heavy Quill editor subtree.
  var _panEnabled = false;

  double get scale => _scale.value;
  bool get isZoomed => _scale.value > 1.02;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    _scale.dispose();
    super.dispose();
  }

  void _onTransform() {
    final next = _transform.value.getMaxScaleOnAxis();
    if ((next - _scale.value).abs() >= 0.001) {
      _scale.value = next;
    }
    final shouldPan = next > 1.02;
    if (shouldPan != _panEnabled) {
      setState(() => _panEnabled = shouldPan);
    }
  }

  void zoomIn() => _zoomBy(1.2);

  void zoomOut() => _zoomBy(1 / 1.2);

  void resetZoom() {
    _transform.value = Matrix4.identity();
  }

  void _zoomBy(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(widget.minScale, widget.maxScale);
    if ((target - current).abs() < 0.001) {
      return;
    }
    final size = context.size;
    if (size == null) {
      return;
    }
    final focal = Offset(size.width / 2, size.height / 2);
    final sceneFocal = _transform.toScene(focal);
    final next = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(target, target, 1, 1)
      ..translateByDouble(-sceneFocal.dx, -sceneFocal.dy, 0, 1);
    _transform.value = next;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          transformationController: _transform,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          // Keep editor gestures at 1×; pan only when zoomed.
          panEnabled: _panEnabled,
          scaleEnabled: true,
          trackpadScrollCausesScale: false,
          clipBehavior: Clip.hardEdge,
          boundaryMargin: const EdgeInsets.all(48),
          child: SizedBox.expand(child: widget.child),
        ),
        PositionedDirectional(
          end: 12,
          bottom: 12,
          child: ValueListenableBuilder<double>(
            valueListenable: _scale,
            builder: (context, scale, _) {
              if (scale <= 1.02) {
                return const SizedBox.shrink();
              }
              return _ZoomBadge(scale: scale, onReset: resetZoom);
            },
          ),
        ),
      ],
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.scale, required this.onReset});

  final double scale;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final percent = (scale * 100).round();

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onReset,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.zoom_out_map, size: 16, color: AppColors.teal),
              const SizedBox(width: 6),
              Text(
                l10n.editorZoomPercent(percent),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
