import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/noteon_pdf_annotations.dart';
import '../data/noteon_pdf_payload.dart';

/// Full-screen PDF viewer with freehand annotation overlay.
///
/// Saves only `annotationsPath` JSON. The PDF file is never rewritten.
class PdfAnnotatorScreen extends ConsumerStatefulWidget {
  const PdfAnnotatorScreen({
    super.key,
    required this.data,
    this.noteId,
  });

  final NoteonPdfData data;
  final int? noteId;

  @override
  ConsumerState<PdfAnnotatorScreen> createState() => _PdfAnnotatorScreenState();
}

class _PdfAnnotatorScreenState extends ConsumerState<PdfAnnotatorScreen> {
  final _pageController = PageController();
  NoteonPdfAnnotations _annotations = NoteonPdfAnnotations.empty();
  NoteonPdfTool _tool = NoteonPdfTool.pen;
  Color _color = const Color(0xFFE11D48);
  double _strokeWidth = 0.008;
  int _pageIndex = 0;
  bool _saving = false;
  bool _loading = true;
  String? _localPdfPath;
  String? _error;

  static const _palette = <Color>[
    Color(0xFFE11D48),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFFACC15),
    Color(0xFF0D9488),
    Color(0xFF1E293B),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await pdfrxFlutterInitialize();
      final media = ref.read(mediaStorageProvider);
      final session = ref.read(unlockedNoteSessionProvider);

      Uint8List? pdfBytes;
      Uint8List? annBytes;
      if (session != null &&
          widget.noteId != null &&
          session.noteId == widget.noteId) {
        pdfBytes = session.mediaBytes[widget.data.pdfPath];
        annBytes = session.mediaBytes[widget.data.annotationsPath];
      }
      pdfBytes ??= await media.readBytesAtRelativePath(widget.data.pdfPath);
      annBytes ??=
          await media.readBytesAtRelativePath(widget.data.annotationsPath);

      if (pdfBytes == null) {
        setState(() {
          _loading = false;
          _error = 'missing';
        });
        return;
      }

      final dir = await getTemporaryDirectory();
      final local = File(
        p.join(dir.path, 'noteon_pdf_${widget.data.id}.pdf'),
      );
      await local.writeAsBytes(pdfBytes, flush: true);

      setState(() {
        _localPdfPath = local.path;
        _annotations = NoteonPdfAnnotations.decode(
          annBytes == null ? '{"version":1,"pages":{}}' : utf8.decode(annBytes),
        );
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'failed';
        });
      }
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final json = _annotations.encode();
      final media = ref.read(mediaStorageProvider);
      final refAnn = await media.writePdfAnnotations(
        annotationsRelativePath: widget.data.annotationsPath,
        annotationsJson: json,
      );
      final session = ref.read(unlockedNoteSessionProvider);
      if (session != null) {
        session.mediaBytes[widget.data.annotationsPath] =
            Uint8List.fromList(utf8.encode(json));
        session.mediaRefs = [
          ...session.mediaRefs.where(
            (r) => r.relativePath != widget.data.annotationsPath,
          ),
          refAnn,
        ];
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pdfAnnotateSaveFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _commitStroke(int pageIndex, NoteonPdfStroke stroke) {
    final current = List<NoteonPdfStroke>.from(
      _annotations.strokesForPage(pageIndex),
    );
    if (_tool == NoteonPdfTool.eraser) {
      current.removeWhere((existing) {
        for (final p in stroke.points) {
          for (final q in existing.points) {
            if ((p - q).distance < 0.03) {
              return true;
            }
          }
        }
        return false;
      });
    } else {
      current.add(stroke);
    }
    setState(() {
      _annotations = _annotations.copyWithPage(pageIndex, current);
    });
  }

  void _undoPage() {
    final strokes = List<NoteonPdfStroke>.from(
      _annotations.strokesForPage(_pageIndex),
    );
    if (strokes.isEmpty) {
      return;
    }
    strokes.removeLast();
    setState(() {
      _annotations = _annotations.copyWithPage(_pageIndex, strokes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = widget.data.title?.trim().isNotEmpty == true
        ? widget.data.title!
        : l10n.pdfDocumentLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          tooltip: l10n.cancel,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          IconButton(
            tooltip: l10n.undo,
            onPressed: _saving ? null : _undoPage,
            icon: const Icon(Icons.undo_rounded),
          ),
          FilledButton(
            onPressed: _saving || _loading || _error != null ? null : _save,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _localPdfPath == null
              ? Center(child: Text(l10n.pdfMissing))
              : Column(
                  children: [
                    Expanded(
                      child: PdfDocumentViewBuilder.file(
                        _localPdfPath!,
                        builder: (context, document) {
                          if (document == null) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return PageView.builder(
                            controller: _pageController,
                            itemCount: document.pages.length,
                            onPageChanged: (i) =>
                                setState(() => _pageIndex = i),
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.all(12),
                                child: _AnnotatedPdfPage(
                                  document: document,
                                  pageNumber: index + 1,
                                  strokes: _annotations.strokesForPage(index),
                                  tool: _tool,
                                  color: _color,
                                  strokeWidth: _strokeWidth,
                                  onStrokeComplete: (stroke) =>
                                      _commitStroke(index, stroke),
                                ),
                              );
                            },
                          );
                        },
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
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Text(
                                  l10n.pdfPageLabel(
                                    _pageIndex + 1,
                                  ),
                                  style: theme.textTheme.labelMedium,
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _ToolChip(
                                        icon: Icons.edit_rounded,
                                        label: l10n.sketchPen,
                                        selected: _tool == NoteonPdfTool.pen,
                                        onPressed: () => setState(() {
                                          _tool = NoteonPdfTool.pen;
                                          _strokeWidth = 0.008;
                                        }),
                                      ),
                                      const SizedBox(width: 6),
                                      _ToolChip(
                                        icon: Icons.highlight_rounded,
                                        label: l10n.sketchHighlighter,
                                        selected:
                                            _tool == NoteonPdfTool.highlighter,
                                        onPressed: () => setState(() {
                                          _tool = NoteonPdfTool.highlighter;
                                          _strokeWidth = 0.028;
                                        }),
                                      ),
                                      const SizedBox(width: 6),
                                      _ToolChip(
                                        icon: Icons.auto_fix_high_outlined,
                                        label: l10n.sketchEraser,
                                        selected: _tool == NoteonPdfTool.eraser,
                                        onPressed: () => setState(
                                          () => _tool = NoteonPdfTool.eraser,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_tool != NoteonPdfTool.eraser) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 32,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _palette.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (context, i) {
                                        final c = _palette[i];
                                        final selected =
                                            c.toARGB32() == _color.toARGB32();
                                        return InkWell(
                                          onTap: () =>
                                              setState(() => _color = c),
                                          customBorder: const CircleBorder(),
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: c,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: selected
                                                    ? AppColors.teal
                                                    : theme.colorScheme.outline,
                                                width: selected ? 2.5 : 1,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
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

class _AnnotatedPdfPage extends StatefulWidget {
  const _AnnotatedPdfPage({
    required this.document,
    required this.pageNumber,
    required this.strokes,
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.onStrokeComplete,
  });

  final PdfDocument document;
  final int pageNumber;
  final List<NoteonPdfStroke> strokes;
  final NoteonPdfTool tool;
  final Color color;
  final double strokeWidth;
  final ValueChanged<NoteonPdfStroke> onStrokeComplete;

  @override
  State<_AnnotatedPdfPage> createState() => _AnnotatedPdfPageState();
}

class _AnnotatedPdfPageState extends State<_AnnotatedPdfPage> {
  List<Offset> _live = [];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            PdfPageView(
              document: widget.document,
              pageNumber: widget.pageNumber,
              decoration: const BoxDecoration(color: Colors.white),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) {
                  setState(() => _live = [d.localPosition]);
                },
                onPanUpdate: (d) {
                  setState(() => _live = [..._live, d.localPosition]);
                },
                onPanEnd: (_) {
                  if (_live.length < 2) {
                    setState(() => _live = []);
                    return;
                  }
                  final size = context.size;
                  if (size == null || size.width <= 0 || size.height <= 0) {
                    setState(() => _live = []);
                    return;
                  }
                  final normalized = [
                    for (final p in _live)
                      Offset(
                        (p.dx / size.width).clamp(0.0, 1.0),
                        (p.dy / size.height).clamp(0.0, 1.0),
                      ),
                  ];
                  widget.onStrokeComplete(
                    NoteonPdfStroke(
                      points: normalized,
                      color: widget.color.toARGB32(),
                      width: widget.strokeWidth,
                      tool: widget.tool,
                    ),
                  );
                  setState(() => _live = []);
                },
                child: CustomPaint(
                  painter: _PdfAnnotationPainter(
                    strokes: widget.strokes,
                    live: _live,
                    liveColor: widget.color,
                    liveWidth: widget.strokeWidth,
                    liveTool: widget.tool,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PdfAnnotationPainter extends CustomPainter {
  _PdfAnnotationPainter({
    required this.strokes,
    required this.live,
    required this.liveColor,
    required this.liveWidth,
    required this.liveTool,
  });

  final List<NoteonPdfStroke> strokes;
  final List<Offset> live;
  final Color liveColor;
  final double liveWidth;
  final NoteonPdfTool liveTool;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, size, stroke);
    }
    if (live.length >= 2 && liveTool != NoteonPdfTool.eraser) {
      _paintStroke(
        canvas,
        size,
        NoteonPdfStroke(
          points: [
            for (final p in live)
              Offset(
                (p.dx / size.width).clamp(0.0, 1.0),
                (p.dy / size.height).clamp(0.0, 1.0),
              ),
          ],
          color: liveColor.toARGB32(),
          width: liveWidth,
          tool: liveTool,
        ),
      );
    } else if (live.length >= 2 && liveTool == NoteonPdfTool.eraser) {
      final path = Path()..moveTo(live.first.dx, live.first.dy);
      for (final p in live.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintStroke(Canvas canvas, Size size, NoteonPdfStroke stroke) {
    if (stroke.points.length < 2) {
      return;
    }
    final path = Path()
      ..moveTo(
        stroke.points.first.dx * size.width,
        stroke.points.first.dy * size.height,
      );
    for (final p in stroke.points.skip(1)) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    final color = Color(stroke.color);
    final paint = Paint()
      ..color = stroke.tool == NoteonPdfTool.highlighter
          ? color.withValues(alpha: 0.35)
          : color
      ..strokeWidth = stroke.width * size.width
      ..style = PaintingStyle.stroke
      ..strokeCap = stroke.tool == NoteonPdfTool.highlighter
          ? StrokeCap.square
          : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PdfAnnotationPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.live != live ||
        oldDelegate.liveColor != liveColor ||
        oldDelegate.liveWidth != liveWidth ||
        oldDelegate.liveTool != liveTool;
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
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
