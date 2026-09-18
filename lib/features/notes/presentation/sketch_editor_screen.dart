import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../data/noteon_ink_stroke_codec.dart';

enum _SketchTool { pen, highlighter, eraser, lasso }

/// Result popped from [SketchEditorScreen] on save.
class SketchEditorResult {
  const SketchEditorResult({
    required this.strokesJson,
    required this.previewPng,
  });

  final String strokesJson;
  final Uint8List previewPng;
}

/// Full-screen freehand / vector sketch editor.
///
/// New saves return stroke JSON + PNG preview for `noteonInk` embeds.
/// Legacy raster sketches in notes remain image embeds and are not opened here.
class SketchEditorScreen extends ConsumerStatefulWidget {
  const SketchEditorScreen({
    super.key,
    this.initialStrokesJson,
  });

  /// Existing stroke JSON when re-editing an ink embed.
  final String? initialStrokesJson;

  @override
  ConsumerState<SketchEditorScreen> createState() => _SketchEditorScreenState();
}

class _SketchEditorScreenState extends ConsumerState<SketchEditorScreen> {
  final DrawingController _controller = DrawingController();
  bool _saving = false;
  Brightness? _appliedBrightness;
  _SketchTool _tool = _SketchTool.pen;
  Color _penColor = const Color(0xFF1E293B);
  Color _highlighterColor = const Color(0xFFFACC15);
  double _strokeWidth = 4;

  List<Map<String, dynamic>> _strokeMaps = [];
  final Set<int> _selected = {};
  List<Offset> _lassoPoints = [];
  bool _lassoActive = false;
  Offset? _dragOrigin;
  List<Map<String, dynamic>>? _dragBaseline;

  static const _penWidths = <double>[2, 4, 8];
  static const _highlighterWidths = <double>[12, 20, 28];
  static const _eraserWidths = <double>[12, 24, 36];

  static const _palette = <Color>[
    Color(0xFF1E293B),
    Color(0xFFE2E8F0),
    AppColors.teal,
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFFACC15),
    Color(0xFFEA580C),
  ];

  @override
  void initState() {
    super.initState();
    final raw = widget.initialStrokesJson;
    if (raw != null && raw.trim().isNotEmpty) {
      _strokeMaps = NoteonInkStrokeCodec.decodeJsonList(raw).toList();
      final contents =
          NoteonInkStrokeCodec.contentsFromJsonList(_strokeMaps);
      if (contents.isNotEmpty) {
        _controller.addContents(contents);
      }
    }
    _applyTool();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_appliedBrightness == brightness) {
      return;
    }
    final isFirst = _appliedBrightness == null;
    _appliedBrightness = brightness;
    if (isFirst) {
      _penColor = brightness == Brightness.dark
          ? const Color(0xFFE2E8F0)
          : const Color(0xFF1E293B);
      _applyTool();
    }
  }

  List<double> get _widthsForTool {
    switch (_tool) {
      case _SketchTool.pen:
        return _penWidths;
      case _SketchTool.highlighter:
        return _highlighterWidths;
      case _SketchTool.eraser:
        return _eraserWidths;
      case _SketchTool.lasso:
        return const [];
    }
  }

  void _selectTool(_SketchTool tool) {
    if (_tool == tool) {
      return;
    }
    setState(() {
      _tool = tool;
      _lassoPoints = [];
      _lassoActive = false;
      _dragOrigin = null;
      _dragBaseline = null;
      if (tool != _SketchTool.lasso) {
        _selected.clear();
      }
      final widths = _widthsForTool;
      if (widths.isNotEmpty && !widths.contains(_strokeWidth)) {
        _strokeWidth = widths[1];
      }
    });
    _applyTool();
  }

  void _selectColor(Color color) {
    setState(() {
      if (_tool == _SketchTool.highlighter) {
        _highlighterColor = color;
      } else {
        _penColor = color;
        if (_tool == _SketchTool.eraser || _tool == _SketchTool.lasso) {
          _tool = _SketchTool.pen;
        }
      }
    });
    _applyTool();
  }

  void _selectWidth(double width) {
    setState(() => _strokeWidth = width);
    _applyTool();
  }

  void _applyTool() {
    switch (_tool) {
      case _SketchTool.pen:
        _controller.setPaintContent(SimpleLine());
        _controller.setStyle(
          color: _penColor,
          strokeWidth: _strokeWidth,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
          isAntiAlias: true,
          blendMode: BlendMode.srcOver,
        );
      case _SketchTool.highlighter:
        _controller.setPaintContent(SimpleLine());
        _controller.setStyle(
          color: _highlighterColor.withValues(alpha: 0.35),
          strokeWidth: _strokeWidth,
          strokeCap: StrokeCap.square,
          strokeJoin: StrokeJoin.round,
          isAntiAlias: true,
          blendMode: BlendMode.srcOver,
        );
      case _SketchTool.eraser:
        _controller.setPaintContent(Eraser());
        _controller.setStyle(
          color: Colors.transparent,
          strokeWidth: _strokeWidth,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
          isAntiAlias: true,
        );
      case _SketchTool.lasso:
        _controller.setPaintContent(EmptyContent());
    }
  }

  void _syncStrokeMapsFromController() {
    _strokeMaps = NoteonInkStrokeCodec.exportActive(
      history: _controller.getHistory,
      currentIndex: _controller.currentIndex,
    );
  }

  void _reloadControllerFromMaps() {
    _controller.clear();
    final contents = NoteonInkStrokeCodec.contentsFromJsonList(_strokeMaps);
    if (contents.isNotEmpty) {
      _controller.addContents(contents);
    }
  }

  void _onLassoStart(Offset local) {
    setState(() {
      if (_selected.isNotEmpty) {
        _dragOrigin = local;
        _dragBaseline = _strokeMaps.map((e) => Map<String, dynamic>.from(
              NoteonInkStrokeCodec.translateStroke(e, Offset.zero),
            )).toList();
        // Deep copy via translate 0
        _dragBaseline = [
          for (final s in _strokeMaps)
            NoteonInkStrokeCodec.translateStroke(s, Offset.zero),
        ];
      } else {
        _lassoActive = true;
        _lassoPoints = [local];
        _dragOrigin = null;
        _dragBaseline = null;
      }
    });
  }

  void _onLassoUpdate(Offset local) {
    if (_dragOrigin != null && _dragBaseline != null && _selected.isNotEmpty) {
      final delta = local - _dragOrigin!;
      setState(() {
        _strokeMaps = [
          for (var i = 0; i < _dragBaseline!.length; i++)
            if (_selected.contains(i))
              NoteonInkStrokeCodec.translateStroke(_dragBaseline![i], delta)
            else
              _dragBaseline![i],
        ];
      });
      _reloadControllerFromMaps();
      return;
    }
    if (_lassoActive) {
      setState(() => _lassoPoints = [..._lassoPoints, local]);
    }
  }

  void _onLassoEnd() {
    if (_dragOrigin != null) {
      setState(() {
        _dragOrigin = null;
        _dragBaseline = null;
      });
      return;
    }
    if (!_lassoActive) {
      return;
    }
    final polygon = List<Offset>.from(_lassoPoints);
    final selected = <int>{};
    for (var i = 0; i < _strokeMaps.length; i++) {
      if (NoteonInkStrokeCodec.strokeIntersectsPolygon(
        _strokeMaps[i],
        polygon,
      )) {
        selected.add(i);
      }
    }
    setState(() {
      _lassoActive = false;
      _lassoPoints = [];
      _selected
        ..clear()
        ..addAll(selected);
    });
  }

  void _deleteSelected() {
    if (_selected.isEmpty) {
      return;
    }
    setState(() {
      _strokeMaps = [
        for (var i = 0; i < _strokeMaps.length; i++)
          if (!_selected.contains(i)) _strokeMaps[i],
      ];
      _selected.clear();
    });
    _reloadControllerFromMaps();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    _syncStrokeMapsFromController();
    if (_strokeMaps.isEmpty && !_controller.canClear()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sketchEmpty)),
      );
      return;
    }
    // Prefer controller history after drawing tools; lasso edits update maps.
    if (_tool != _SketchTool.lasso || _strokeMaps.isEmpty) {
      _syncStrokeMapsFromController();
    }

    if (_strokeMaps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sketchEmpty)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Ensure board reflects maps (lasso may have mutated maps).
      _reloadControllerFromMaps();
      await Future<void>.delayed(const Duration(milliseconds: 16));

      final data = await _controller.getImageData(
        format: ui.ImageByteFormat.png,
        pixelRatio: 2,
      );
      if (data == null) {
        throw StateError('Failed to export sketch');
      }

      final strokesJson =
          NoteonInkStrokeCodec.encodeJsonList(_strokeMaps);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        SketchEditorResult(
          strokesJson: strokesJson,
          previewPng: data.buffer.asUint8List(),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sketchSaveFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canvasBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final paperColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final activeColor = _tool == _SketchTool.highlighter
        ? _highlighterColor
        : _penColor;
    final isLasso = _tool == _SketchTool.lasso;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.newSketch,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          tooltip: l10n.cancel,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          if (isLasso && _selected.isNotEmpty)
            IconButton(
              tooltip: l10n.inkDeleteSelected,
              onPressed: _saving ? null : _deleteSelected,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.save),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: canvasBg,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            DrawingBoard(
                              controller: _controller,
                              background: Container(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                color: paperColor,
                              ),
                              boardPanEnabled: false,
                              boardScaleEnabled: false,
                            ),
                            if (isLasso)
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (d) =>
                                      _onLassoStart(d.localPosition),
                                  onPanUpdate: (d) =>
                                      _onLassoUpdate(d.localPosition),
                                  onPanEnd: (_) => _onLassoEnd(),
                                  child: CustomPaint(
                                    painter: _LassoPainter(
                                      points: _lassoPoints,
                                      selectedCount: _selected.length,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: AppRadii.control,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ToolChip(
                              icon: Icons.edit_rounded,
                              label: l10n.sketchPen,
                              selected: _tool == _SketchTool.pen,
                              onPressed: () => _selectTool(_SketchTool.pen),
                            ),
                            const SizedBox(width: 6),
                            _ToolChip(
                              icon: Icons.highlight_rounded,
                              label: l10n.sketchHighlighter,
                              selected: _tool == _SketchTool.highlighter,
                              onPressed: () =>
                                  _selectTool(_SketchTool.highlighter),
                            ),
                            const SizedBox(width: 6),
                            _ToolChip(
                              icon: Icons.auto_fix_high_outlined,
                              label: l10n.sketchEraser,
                              selected: _tool == _SketchTool.eraser,
                              onPressed: () =>
                                  _selectTool(_SketchTool.eraser),
                            ),
                            const SizedBox(width: 6),
                            _ToolChip(
                              icon: Icons.gesture_rounded,
                              label: l10n.sketchLasso,
                              selected: _tool == _SketchTool.lasso,
                              onPressed: () {
                                _syncStrokeMapsFromController();
                                _selectTool(_SketchTool.lasso);
                              },
                            ),
                            const SizedBox(width: 8),
                            _IconAction(
                              icon: Icons.undo_rounded,
                              tooltip: l10n.undo,
                              onPressed: () {
                                if (_controller.canUndo()) {
                                  _controller.undo();
                                  _syncStrokeMapsFromController();
                                  setState(() => _selected.clear());
                                }
                              },
                            ),
                            _IconAction(
                              icon: Icons.redo_rounded,
                              tooltip: l10n.redo,
                              onPressed: () {
                                if (_controller.canRedo()) {
                                  _controller.redo();
                                  _syncStrokeMapsFromController();
                                  setState(() => _selected.clear());
                                }
                              },
                            ),
                            _IconAction(
                              icon: Icons.delete_outline_rounded,
                              tooltip: l10n.clearCanvas,
                              onPressed: () {
                                if (_controller.canClear()) {
                                  _controller.clear();
                                  setState(() {
                                    _strokeMaps = [];
                                    _selected.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      if (!isLasso) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _palette.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final color = _palette[index];
                              final selected =
                                  _tool != _SketchTool.eraser &&
                                      color.toARGB32() ==
                                          activeColor.toARGB32();
                              return _ColorSwatch(
                                color: color,
                                selected: selected,
                                onTap: () => _selectColor(color),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final width in _widthsForTool) ...[
                              _WidthChip(
                                width: width,
                                selected: _strokeWidth == width,
                                onPressed: () => _selectWidth(width),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          _selected.isEmpty
                              ? l10n.inkLassoHint
                              : l10n.inkLassoSelected(_selected.length),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LassoPainter extends CustomPainter {
  _LassoPainter({required this.points, required this.selectedCount});

  final List<Offset> points;
  final int selectedCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.teal
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.teal.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
    }
    if (selectedCount > 0) {
      final text = TextPainter(
        text: TextSpan(
          text: '$selectedCount',
          style: const TextStyle(
            color: AppColors.teal,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, const Offset(12, 12));
    }
  }

  @override
  bool shouldRepaint(covariant _LassoPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedCount != selectedCount;
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => onPressed(),
      selectedColor: AppColors.teal.withValues(alpha: 0.2),
      side: BorderSide(
        color: selected
            ? AppColors.teal
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: AppColors.teal),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outline;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.teal : borderColor,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _WidthChip extends StatelessWidget {
  const _WidthChip({
    required this.width,
    required this.selected,
    required this.onPressed,
  });

  final double width;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 44,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? AppColors.teal.withValues(alpha: 0.15)
              : theme.colorScheme.surface,
          border: Border.all(
            color: selected
                ? AppColors.teal
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Container(
          width: 22,
          height: (width / 4).clamp(2.0, 10.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
