import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noteon/features/notes/presentation/note_editor_browse_caret_sync.dart';

/// Zoom/pan × browse-caret investigation (evidence only — no product change).
///
/// Soft assertions only: tests must not fail the suite merely because the
/// layout-fraction anchor sits outside the clip. Evidence is printed as
/// `ZOOM_INV[...]` lines for CI logs / AI reports.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  QuillController longNote({int paragraphs = 80}) {
    final controller = QuillController(
      document: Document.fromJson([
        {
          'insert': List.generate(
            paragraphs,
            (i) => 'Paragraph $i zoom-pan investigation line.\n',
          ).join(),
        },
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );
    controller.updateSelection(
      TextSelection.collapsed(offset: controller.document.length - 1),
      ChangeSource.local,
    );
    return controller;
  }

  /// Mirrors production: ClipRect → translucent Listener → Transform → editor.
  Future<({GlobalKey hostKey, NoteEditorBrowseCaretSync sync})> pumpZoomed(
    WidgetTester tester, {
    required QuillController controller,
    required double scale,
    Offset translation = Offset.zero,
    double height = 400,
    double width = 360,
  }) async {
    final hostKey = GlobalKey();
    final scrollController = ScrollController();
    final focusNode = FocusNode();
    final sync = NoteEditorBrowseCaretSync(
      controller: controller,
      editorHostKey: hostKey,
      scrollController: scrollController,
    );
    addTearDown(() {
      sync.dispose();
      scrollController.dispose();
      focusNode.dispose();
      controller.dispose();
    });

    final focal = Offset(width / 2, height * 0.35);
    final scene = Offset(focal.dx - translation.dx, focal.dy - translation.dy);
    final matrix = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: height,
            width: width,
            child: ClipRect(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerSignal: (signal) {
                  if (signal is PointerScrollEvent) {
                    sync.onPointerScroll(signal);
                  }
                },
                child: Transform(
                  transform: matrix,
                  child: SizedBox.expand(
                    child: KeyedSubtree(
                      key: hostKey,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: sync.onScrollNotification,
                        child: QuillEditor.basic(
                          controller: controller,
                          focusNode: focusNode,
                          scrollController: scrollController,
                          config: const QuillEditorConfig(
                            scrollable: true,
                            expands: false,
                            autoFocus: false,
                            padding: EdgeInsets.zero,
                            scrollPhysics: BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (hostKey: hostKey, sync: sync);
  }

  RenderEditor requireEditor(GlobalKey hostKey) {
    final ctx = hostKey.currentContext!;
    RenderEditor? found;
    void visit(Element e) {
      if (found != null) {
        return;
      }
      if (e.renderObject is RenderEditor) {
        found = e.renderObject as RenderEditor;
        return;
      }
      e.visitChildren(visit);
    }

    ctx.visitChildElements(visit);
    return found!;
  }

  Rect clipRectOf(WidgetTester tester) {
    final clip =
        tester.renderObject<RenderClipRect>(find.byType(ClipRect).first);
    return clip.localToGlobal(Offset.zero) & clip.size;
  }

  Offset layoutAnchorGlobal(RenderEditor editor) {
    final local = Offset(
      editor.size.width / 2,
      (editor.size.height * 0.28).clamp(12.0, editor.size.height - 12.0),
    );
    return editor.localToGlobal(local);
  }

  Offset clipAnchorGlobal(Rect clip) =>
      Offset(clip.center.dx, clip.top + clip.height * 0.28);

  Map<String, Object?> measure({
    required String label,
    required RenderEditor editor,
    required Rect clip,
    required QuillController controller,
  }) {
    final layoutG = layoutAnchorGlobal(editor);
    final clipG = clipAnchorGlobal(clip);
    final layoutInClip = clip.contains(layoutG);
    final layoutOff = safeBrowseCaretOffset(
      controller.document,
      editor.getPositionForOffset(layoutG).offset,
    );
    final clipOff = safeBrowseCaretOffset(
      controller.document,
      editor.getPositionForOffset(clipG).offset,
    );
    final caret = controller.selection.baseOffset;
    final docDelta = (layoutOff - clipOff).abs();
    final caretVsClip = (caret - clipOff).abs();
    final caretVsLayout = (caret - layoutOff).abs();

    debugPrint(
      'ZOOM_INV[$label] layoutInClip=$layoutInClip '
      'layoutG=$layoutG clipG=$clipG clip=$clip '
      'caret=$caret layoutOff=$layoutOff clipOff=$clipOff '
      'docDelta=$docDelta caretVsClip=$caretVsClip '
      'caretVsLayout=$caretVsLayout',
    );

    return {
      'layoutInClip': layoutInClip,
      'caret': caret,
      'layoutOff': layoutOff,
      'clipOff': clipOff,
      'docDelta': docDelta,
      'caretVsClip': caretVsClip,
      'caretVsLayout': caretVsLayout,
      'relocated': caret != controller.document.length - 1,
    };
  }

  Future<void> tryBrowseDrag(WidgetTester tester, {double dy = 200}) async {
    // Drag from the clipped viewport center (what the user sees), matching
    // production translucent hit coverage over the zoom viewport.
    final box = tester.renderObject(find.byType(ClipRect).first) as RenderBox;
    final start = box.localToGlobal(box.size.center(Offset.zero));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(Offset(0, dy));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('zoom/pan browse-caret investigation', () {
    testWidgets('scenario matrix: record layout vs clip under zoom/pan',
        (tester) async {
      final scenarios = <({
        String name,
        double scale,
        Offset translation,
        double dy,
      })>[
        (name: '1x', scale: 1.0, translation: Offset.zero, dy: 220),
        (name: 'zoom1.5', scale: 1.5, translation: Offset.zero, dy: 200),
        (name: 'zoom2.4', scale: 2.4, translation: Offset.zero, dy: 160),
        (
          name: 'zoom2.4_vpan',
          scale: 2.4,
          translation: const Offset(0, 220),
          dy: 180
        ),
        (
          name: 'zoom2.2_hpan',
          scale: 2.2,
          translation: const Offset(140, 40),
          dy: 180
        ),
        (
          name: 'zoom2.4_diag',
          scale: 2.4,
          translation: const Offset(80, 200),
          dy: 180
        ),
      ];

      for (final s in scenarios) {
        final controller = longNote();
        final eof = controller.document.length - 1;
        final pumped = await pumpZoomed(
          tester,
          controller: controller,
          scale: s.scale,
          translation: s.translation,
        );
        final editor = requireEditor(pumped.hostKey);
        final clip = clipRectOf(tester);

        measure(
          label: '${s.name}_pre',
          editor: editor,
          clip: clip,
          controller: controller,
        );

        await tryBrowseDrag(tester, dy: s.dy);
        final post = measure(
          label: '${s.name}_post',
          editor: editor,
          clip: clip,
          controller: controller,
        );

        final browsed = controller.selection.baseOffset != eof;
        debugPrint(
          'ZOOM_INV[${s.name}_summary] browsed=$browsed '
          'layoutInClip=${post['layoutInClip']} '
          'docDelta=${post['docDelta']} '
          'caretVsClip=${post['caretVsClip']} '
          'caretVsLayout=${post['caretVsLayout']}',
        );

        // Soft product invariants (always hold):
        expect(controller.selection.isCollapsed, isTrue);
        expect(controller.skipRequestKeyboard, isFalse);
      }
    });

    testWidgets('when browse relocates under moderate zoom, typing stays put',
        (tester) async {
      final controller = longNote();
      final eof = controller.document.length - 1;
      await pumpZoomed(tester, controller: controller, scale: 1.6);
      await tryBrowseDrag(tester, dy: 220);
      final at = controller.selection.baseOffset;
      // If browse did not relocate (hit/transform edge), skip typing check.
      if (at >= eof) {
        debugPrint('ZOOM_INV[type_after] skipped_no_browse_relocate');
        expect(controller.selection.isCollapsed, isTrue);
        return;
      }
      controller.replaceText(
        at,
        0,
        'KEEP',
        TextSelection.collapsed(offset: at + 4),
      );
      await tester.pump();
      expect(controller.document.toPlainText().contains('KEEP'), isTrue);
      expect(controller.selection.baseOffset, lessThan(eof - 20));
      expect(controller.selection.baseOffset, closeTo(at + 4, 6));
      debugPrint('ZOOM_INV[type_after] ok at=$at');
    });

    testWidgets('heavy pan: type after browse does not jump to EOF when relocated',
        (tester) async {
      final controller = longNote();
      final eof = controller.document.length - 1;
      final pumped = await pumpZoomed(
        tester,
        controller: controller,
        scale: 2.4,
        translation: const Offset(0, 200),
      );
      final editor = requireEditor(pumped.hostKey);
      final clip = clipRectOf(tester);
      measure(
        label: 'heavy_pan_pre',
        editor: editor,
        clip: clip,
        controller: controller,
      );

      await tryBrowseDrag(tester, dy: 200);
      final post = measure(
        label: 'heavy_pan_post',
        editor: editor,
        clip: clip,
        controller: controller,
      );
      final at = controller.selection.baseOffset;
      final relocated = at < eof;

      if (relocated) {
        controller.replaceText(
          at,
          0,
          'PAN',
          TextSelection.collapsed(offset: at + 3),
        );
        await tester.pump();
        expect(controller.document.toPlainText().contains('PAN'), isTrue);
        expect(controller.selection.baseOffset, lessThan(eof - 20));
      }

      debugPrint(
        'ZOOM_INV[heavy_pan_type] relocated=$relocated '
        'layoutInClip=${post['layoutInClip']} '
        'docDelta=${post['docDelta']} caretVsClip=${post['caretVsClip']}',
      );
      expect(controller.selection.isCollapsed, isTrue);
    });

    testWidgets('selection preserved under zoom+pan browse attempt',
        (tester) async {
      final controller = longNote();
      controller.updateSelection(
        const TextSelection(baseOffset: 40, extentOffset: 70),
        ChangeSource.local,
      );
      await pumpZoomed(
        tester,
        controller: controller,
        scale: 2.0,
        translation: const Offset(0, 180),
      );
      await tryBrowseDrag(tester, dy: 160);
      expect(controller.selection.baseOffset, 40);
      expect(controller.selection.extentOffset, 70);
    });

    testWidgets('synthetic model disagreement under heavy pan (evidence)',
        (tester) async {
      final controller = longNote();
      final pumped = await pumpZoomed(
        tester,
        controller: controller,
        scale: 2.5,
        translation: const Offset(0, 260),
      );
      final editor = requireEditor(pumped.hostKey);
      final clip = clipRectOf(tester);
      final m = measure(
        label: 'synthetic_disagree',
        editor: editor,
        clip: clip,
        controller: controller,
      );

      // Document the fork; do not require a specific magnitude.
      expect(m['docDelta'] as int, greaterThanOrEqualTo(0));
      debugPrint(
        'ZOOM_INV[verdict_hint] '
        'layoutOutsideClip=${!(m['layoutInClip'] as bool)} '
        'modelsDisagreeChars=${m['docDelta']}',
      );
    });

    testWidgets('repeated browse attempts while zoomed remain safe',
        (tester) async {
      final controller = longNote(paragraphs: 100);
      await pumpZoomed(
        tester,
        controller: controller,
        scale: 2.0,
        translation: const Offset(0, 160),
      );
      await tryBrowseDrag(tester, dy: 200);
      final a = controller.selection.baseOffset;
      controller.updateSelection(
        TextSelection.collapsed(offset: controller.document.length - 1),
        ChangeSource.local,
      );
      await tester.pump();
      await tryBrowseDrag(tester, dy: 200);
      final b = controller.selection.baseOffset;
      debugPrint('ZOOM_INV[repeated] a=$a b=$b');
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.skipRequestKeyboard, isFalse);
    });
  });
}
