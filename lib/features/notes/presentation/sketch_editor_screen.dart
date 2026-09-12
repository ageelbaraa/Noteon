import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/media_providers.dart';
import '../../../core/theme/app_colors.dart';

/// Full-screen freehand sketch editor. Pops with a relative media path on save.
class SketchEditorScreen extends ConsumerStatefulWidget {
  const SketchEditorScreen({super.key});

  @override
  ConsumerState<SketchEditorScreen> createState() => _SketchEditorScreenState();
}

class _SketchEditorScreenState extends ConsumerState<SketchEditorScreen> {
  final DrawingController _controller = DrawingController();
  bool _saving = false;
  Brightness? _appliedBrightness;

  @override
  void initState() {
    super.initState();
    _controller.setPaintContent(SimpleLine());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_appliedBrightness == brightness) {
      return;
    }
    _appliedBrightness = brightness;
    final strokeColor = brightness == Brightness.dark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF1E293B);
    _controller.setStyle(
      color: strokeColor,
      strokeWidth: 4,
      strokeCap: StrokeCap.round,
      strokeJoin: StrokeJoin.round,
      isAntiAlias: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_controller.canClear()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sketchEmpty)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final data = await _controller.getImageData(
        format: ui.ImageByteFormat.png,
        pixelRatio: 2,
      );
      if (data == null) {
        throw StateError('Failed to export sketch');
      }

      final media = ref.read(mediaStorageProvider);
      final refMedia = await media.importSketchPng(data.buffer.asUint8List());
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(refMedia.relativePath);
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
                        return DrawingBoard(
                          controller: _controller,
                          background: Container(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            color: paperColor,
                          ),
                          boardPanEnabled: false,
                          boardScaleEnabled: false,
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
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ToolButton(
                        icon: Icons.undo_rounded,
                        label: l10n.undo,
                        onPressed: () {
                          if (_controller.canUndo()) {
                            _controller.undo();
                            setState(() {});
                          }
                        },
                      ),
                      _ToolButton(
                        icon: Icons.redo_rounded,
                        label: l10n.redo,
                        onPressed: () {
                          if (_controller.canRedo()) {
                            _controller.redo();
                            setState(() {});
                          }
                        },
                      ),
                      _ToolButton(
                        icon: Icons.delete_outline_rounded,
                        label: l10n.clearCanvas,
                        onPressed: () {
                          if (_controller.canClear()) {
                            _controller.clear();
                            setState(() {});
                          }
                        },
                      ),
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

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: AppColors.teal),
      label: Text(label),
    );
  }
}
