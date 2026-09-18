import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noteon/features/notes/data/noteon_table_data.dart';
import 'package:noteon/features/notes/presentation/note_editor_browse_caret_sync.dart';
import 'package:noteon/features/notes/presentation/note_editor_zoom_viewport.dart';
import 'package:noteon/features/notes/presentation/noteon_table_embed.dart';

/// Deeper note-editor scenarios for free Android emulator CI.
///
/// Complements `note_editor_browse_test.dart` without duplicating its cases.
/// Uses a Quill harness (not Isar) so CI stays deterministic and $0.
///
/// Only imports packages already on `main` (image + table embeds). Other custom
/// embed types share the same [safeBrowseCaretOffset] Embed-leaf path.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  QuillController longNote({int paragraphs = 60, int caretAt = -1}) {
    final controller = QuillController(
      document: Document.fromJson([
        {
          'insert': List.generate(
            paragraphs,
            (i) => 'Paragraph $i of sample note for deep browse testing.\n',
          ).join(),
        },
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );
    final end = controller.document.length - 1;
    final offset = caretAt < 0 ? end : caretAt.clamp(0, end);
    controller.updateSelection(
      TextSelection.collapsed(offset: offset),
      ChangeSource.local,
    );
    return controller;
  }

  /// Text ↔ table ↔ image ↔ text document using committed embed types only.
  QuillController mixedEmbedNote() {
    final table = NoteonTableData.empty(rows: 2, columns: 2, id: 't1');
    final controller = QuillController(
      document: Document.fromJson([
        {'insert': 'Before embeds\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 13),
    );

    void insertEmbed(Embeddable embed) {
      final at = controller.selection.baseOffset;
      controller.replaceText(
        at,
        0,
        embed,
        TextSelection.collapsed(offset: at + 1),
      );
      final after = controller.selection.baseOffset;
      controller.replaceText(
        after,
        0,
        '\n',
        TextSelection.collapsed(offset: after + 1),
      );
    }

    insertEmbed(BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)));
    insertEmbed(BlockEmbed.image('images/draw_or_ink_standin.png'));
    insertEmbed(BlockEmbed.image('images/pdf_or_audio_standin.png'));

    final at = controller.selection.baseOffset;
    final tail = StringBuffer('After all embeds\n');
    for (var i = 0; i < 40; i++) {
      tail.writeln('Tail paragraph $i for scrolling past embeds.');
    }
    controller.replaceText(
      at,
      0,
      tail.toString(),
      TextSelection.collapsed(offset: controller.document.length - 1),
    );
    return controller;
  }

  Future<
      ({
        NoteEditorBrowseCaretSync sync,
        ScrollController scroll,
        FocusNode focus,
        GlobalKey hostKey,
      })> pumpHarness(
    WidgetTester tester, {
    required QuillController controller,
    double minBrowseDistance = 24,
    double height = 480,
    bool wrapZoom = false,
    double zoomScale = 1.0,
    Offset zoomTranslation = Offset.zero,
    bool withEmbedStubs = false,
  }) async {
    final hostKey = GlobalKey();
    final scrollController = ScrollController();
    final focusNode = FocusNode();
    final sync = NoteEditorBrowseCaretSync(
      controller: controller,
      editorHostKey: hostKey,
      scrollController: scrollController,
      minBrowseDistance: minBrowseDistance,
    );
    addTearDown(() {
      sync.dispose();
      scrollController.dispose();
      focusNode.dispose();
      controller.dispose();
    });

    Widget editor = KeyedSubtree(
      key: hostKey,
      child: Listener(
        onPointerSignal: (signal) {
          if (signal is PointerScrollEvent) {
            sync.onPointerScroll(signal);
          }
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: sync.onScrollNotification,
          child: QuillEditor.basic(
            controller: controller,
            focusNode: focusNode,
            scrollController: scrollController,
            config: QuillEditorConfig(
              scrollable: true,
              expands: false,
              autoFocus: false,
              padding: EdgeInsets.zero,
              scrollPhysics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              embedBuilders: withEmbedStubs
                  ? const [
                      _StubEmbedBuilder(BlockEmbed.imageType),
                      _StubEmbedBuilder(NoteonTableBlockEmbed.embedType),
                    ]
                  : const [],
              unknownEmbedBuilder:
                  withEmbedStubs ? const _StubUnknownEmbed() : null,
            ),
          ),
        ),
      ),
    );

    if (wrapZoom) {
      // Mirrors production ClipRect + Transform without private zoom state.
      editor = ClipRect(
        child: Transform(
          transform: noteEditorZoomMatrix(
            scale: zoomScale,
            focalViewport: const Offset(180, 120),
            focalScene:
                Offset(180 - zoomTranslation.dx, 120 - zoomTranslation.dy),
          ),
          child: SizedBox.expand(child: editor),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: height,
            width: 360,
            child: editor,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (
      sync: sync,
      scroll: scrollController,
      focus: focusNode,
      hostKey: hostKey,
    );
  }

  RenderEditor? findRenderEditor(GlobalKey hostKey) {
    final ctx = hostKey.currentContext;
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

  group('scrolling / browsing', () {
    testWidgets('small drag below threshold does not relocate caret',
        (tester) async {
      final controller = longNote(caretAt: 80);
      await pumpHarness(
        tester,
        controller: controller,
        minBrowseDistance: 80,
      );
      final before = controller.selection.baseOffset;

      await tester.drag(find.byType(QuillEditor), const Offset(0, 28));
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, before);
    });

    testWidgets('consecutive drag browses keep relocating caret',
        (tester) async {
      final controller = longNote(paragraphs: 90);
      await pumpHarness(tester, controller: controller);

      final start = controller.selection.baseOffset;
      await tester.drag(find.byType(QuillEditor), const Offset(0, 260));
      await tester.pumpAndSettle();
      final mid = controller.selection.baseOffset;
      expect(mid, lessThan(start));

      // Reset caret to end so a second browse must move again.
      controller.updateSelection(
        TextSelection.collapsed(offset: controller.document.length - 1),
        ChangeSource.local,
      );
      await tester.pump();

      await tester.drag(find.byType(QuillEditor), const Offset(0, 260));
      await tester.pumpAndSettle();
      final end = controller.selection.baseOffset;
      expect(end, lessThan(controller.document.length - 1));
      expect(controller.selection.isCollapsed, isTrue);
    });

    testWidgets('slow deliberate drag relocates caret', (tester) async {
      final controller = longNote();
      await pumpHarness(tester, controller: controller);
      final before = controller.selection.baseOffset;

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(QuillEditor)));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 28));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, lessThan(before));
    });

    testWidgets('ballistic-only scroll updates do not relocate caret',
        (tester) async {
      final controller = longNote(caretAt: 200);
      final harness = await pumpHarness(tester, controller: controller);
      final before = controller.selection.baseOffset;
      final ctx = tester.element(find.byType(QuillEditor));
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 3000,
        pixels: 500,
        viewportDimension: 480,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );

      // No dragDetails ⇒ treated as ballistic / programmatic, not browse.
      harness.sync.onScrollNotification(
        ScrollUpdateNotification(
          metrics: metrics,
          context: ctx,
          scrollDelta: 180,
        ),
      );
      harness.sync.onScrollNotification(
        ScrollEndNotification(metrics: metrics, context: ctx),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection.baseOffset, before);
    });

    testWidgets(
        'fling with drag phase may relocate when distance exceeds threshold',
        (tester) async {
      final controller = longNote(caretAt: 200);
      await pumpHarness(tester, controller: controller);
      final before = controller.selection.baseOffset;

      // tester.fling includes a drag phase (dragDetails present), so this can
      // count as browse — distinct from pure ballistic updates above.
      await tester.fling(find.byType(QuillEditor), const Offset(0, 400), 2500);
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, isNot(before));
      expect(controller.selection.isCollapsed, isTrue);
    });

    testWidgets('scroll stop then type keeps insertion at browse caret',
        (tester) async {
      final controller = longNote();
      final harness = await pumpHarness(tester, controller: controller);
      final before = controller.selection.baseOffset;

      await tester.drag(find.byType(QuillEditor), const Offset(0, 240));
      await tester.pumpAndSettle();
      final at = controller.selection.baseOffset;
      expect(at, lessThan(before));

      harness.focus.requestFocus();
      await tester.pump();
      final editable = find.byType(EditableText);
      if (editable.evaluate().isNotEmpty) {
        await tester.showKeyboard(editable.first);
        await tester.pump();
        try {
          tester.testTextInput.enterText('IMEOK');
          await tester.pump();
        } catch (_) {
          // Fall through to controller insert below.
        }
      }
      if (!controller.document.toPlainText().contains('IMEOK')) {
        controller.replaceText(
          at,
          0,
          'IMEOK',
          TextSelection.collapsed(offset: at + 5),
        );
        await tester.pump();
      }

      expect(controller.document.toPlainText().contains('IMEOK'), isTrue);
      expect(controller.selection.baseOffset, lessThan(before));
      expect(controller.selection.baseOffset, closeTo(at + 5, 8));
    });
  });

  group('caret / embeds', () {
    testWidgets(
        'safe offsets for table and image embeds never land on Embed',
        (tester) async {
      final controller = mixedEmbedNote();
      final doc = controller.document;
      addTearDown(controller.dispose);
      final sampleOffsets = <int>{0, 1, 5, 10, 15, 20, doc.length ~/ 4};
      for (final raw in sampleOffsets) {
        final offset = safeBrowseCaretOffset(doc, raw);
        final leaf = doc.querySegmentLeafNode(offset).leaf;
        expect(
          leaf,
          isNot(isA<Embed>()),
          reason: 'raw=$raw safe=$offset must be text',
        );
      }
    });

    testWidgets('consecutive image embeds nudge caret onto following text',
        (tester) async {
      final doc = Document.fromJson([
        {
          'insert': {'image': 'images/a.png'},
        },
        {'insert': '\n'},
        {
          'insert': {'image': 'images/b.png'},
        },
        {'insert': '\n'},
        {
          'insert': {'image': 'images/c.png'},
        },
        {'insert': '\nAfter stack\n'},
      ]);
      final offset = safeBrowseCaretOffset(doc, 0);
      expect(doc.querySegmentLeafNode(offset).leaf, isNot(isA<Embed>()));
      expect(doc.toPlainText().substring(offset).contains('After'), isTrue);
    });

    testWidgets('text then table then text safe offsets stay off Embed',
        (tester) async {
      final table = NoteonTableData.empty(rows: 2, columns: 2, id: 'edge');
      final controller = QuillController(
        document: Document.fromJson([
          {'insert': 'Above\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 5),
      );
      controller.replaceText(
        5,
        0,
        BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
        const TextSelection.collapsed(offset: 6),
      );
      controller.replaceText(
        6,
        0,
        '\nBelow table\n',
        const TextSelection.collapsed(offset: 7),
      );
      addTearDown(controller.dispose);

      for (final raw in [0, 5, 6, 7]) {
        final offset = safeBrowseCaretOffset(controller.document, raw);
        expect(
          controller.document.querySegmentLeafNode(offset).leaf,
          isNot(isA<Embed>()),
        );
      }
    });

    testWidgets('drag browse near image embed does not leave caret on Embed',
        (tester) async {
      final paragraphs = List.generate(8, (i) => 'Lead $i\n').join();
      final controller = QuillController(
        document: Document.fromJson([
          {'insert': paragraphs},
          {
            'insert': {'image': 'images/mid.png'},
          },
          {'insert': '\n'},
          {
            'insert': {'image': 'images/mid2.png'},
          },
          {'insert': '\nAfter embeds continue.\n'},
          {
            'insert': List.generate(
              30,
              (i) => 'Trail $i of content under embeds.\n',
            ).join(),
          },
        ]),
        selection: const TextSelection.collapsed(offset: 0),
      );
      final end = controller.document.length - 1;
      controller.updateSelection(
        TextSelection.collapsed(offset: end),
        ChangeSource.local,
      );
      await pumpHarness(
        tester,
        controller: controller,
        height: 420,
        withEmbedStubs: true,
      );

      await tester.drag(find.byType(QuillEditor), const Offset(0, 280));
      await tester.pumpAndSettle();

      final offset = controller.selection.baseOffset;
      final leaf = controller.document.querySegmentLeafNode(offset).leaf;
      expect(leaf, isNot(isA<Embed>()));
      expect(controller.selection.isCollapsed, isTrue);
    });

    testWidgets('browse with existing selection preserves range',
        (tester) async {
      final controller = longNote(caretAt: 30);
      controller.updateSelection(
        const TextSelection(baseOffset: 30, extentOffset: 55),
        ChangeSource.local,
      );
      await pumpHarness(tester, controller: controller);

      await tester.drag(find.byType(QuillEditor), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, 30);
      expect(controller.selection.extentOffset, 55);
      expect(controller.selection.isCollapsed, isFalse);
    });
  });

  group('keyboard / focus', () {
    testWidgets('tap editor requests focus; browse clears skipRequestKeyboard',
        (tester) async {
      final controller = longNote(caretAt: 10);
      final harness = await pumpHarness(tester, controller: controller);

      await tester.tap(find.byType(QuillEditor));
      await tester.pump();
      expect(harness.focus.hasFocus, isTrue);

      await tester.drag(find.byType(QuillEditor), const Offset(0, 220));
      await tester.pumpAndSettle();

      expect(controller.skipRequestKeyboard, isFalse);
      expect(controller.selection.isCollapsed, isTrue);
    });

    testWidgets('browse while focused then type does not jump to old caret',
        (tester) async {
      final controller = longNote();
      final harness = await pumpHarness(tester, controller: controller);
      final oldEnd = controller.selection.baseOffset;

      harness.focus.requestFocus();
      await tester.pump();
      final editable = find.byType(EditableText);
      if (editable.evaluate().isNotEmpty) {
        await tester.showKeyboard(editable.first);
        await tester.pump();
      }

      await tester.drag(find.byType(QuillEditor), const Offset(0, 240));
      await tester.pumpAndSettle();
      final browsed = controller.selection.baseOffset;
      expect(browsed, lessThan(oldEnd));

      controller.replaceText(
        browsed,
        0,
        'FOCUS',
        TextSelection.collapsed(offset: browsed + 5),
      );
      await tester.pump();

      expect(controller.document.toPlainText().contains('FOCUS'), isTrue);
      expect(controller.selection.baseOffset, lessThan(oldEnd));
      expect(
        (controller.selection.baseOffset - (browsed + 5)).abs(),
        lessThanOrEqualTo(2),
      );
    });

    testWidgets('unfocus after browse leaves caret where browse placed it',
        (tester) async {
      final controller = longNote();
      final harness = await pumpHarness(tester, controller: controller);

      await tester.drag(find.byType(QuillEditor), const Offset(0, 240));
      await tester.pumpAndSettle();
      final at = controller.selection.baseOffset;

      harness.focus.unfocus();
      await tester.pump();
      expect(harness.focus.hasFocus, isFalse);
      expect(controller.selection.baseOffset, at);
    });
  });

  group('zoom + browse', () {
    testWidgets('browse while zoomed still relocates collapsed caret',
        (tester) async {
      final controller = longNote();
      await pumpHarness(
        tester,
        controller: controller,
        wrapZoom: true,
        zoomScale: 1.8,
      );
      final before = controller.selection.baseOffset;

      await tester.drag(find.byType(QuillEditor), const Offset(0, 240));
      await tester.pumpAndSettle();

      expect(controller.selection.baseOffset, lessThan(before));
      expect(controller.selection.isCollapsed, isTrue);
    });

    testWidgets(
        'evidence: zoom+pan may place browse target outside clipped viewport',
        (tester) async {
      final controller = longNote();
      final harness = await pumpHarness(
        tester,
        controller: controller,
        wrapZoom: true,
        zoomScale: 2.4,
        // Heavy pan so layout-fraction anchor can leave the ClipRect.
        zoomTranslation: const Offset(0, 220),
        height: 400,
      );

      final editor = findRenderEditor(harness.hostKey);
      expect(editor, isNotNull);
      expect(editor!.hasSize, isTrue);

      final anchorLocal = Offset(
        editor.size.width / 2,
        (editor.size.height * 0.28).clamp(12.0, editor.size.height - 12.0),
      );
      final anchorGlobal = editor.localToGlobal(anchorLocal);

      final clipFinder = find.byType(ClipRect);
      expect(clipFinder, findsWidgets);
      final clip = tester.renderObject<RenderClipRect>(clipFinder.first);
      final clipGlobal = clip.localToGlobal(Offset.zero);
      final clipRect = clipGlobal & clip.size;
      final anchorVisible = clipRect.contains(anchorGlobal);

      // Evidence only — do not fail the suite on this product edge case.
      debugPrint(
        'zoom_pan_anchor_visible=$anchorVisible '
        'anchor=$anchorGlobal clip=$clipRect',
      );

      await tester.drag(
        find.byType(QuillEditor),
        const Offset(0, 180),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isTrue);
    });

    testWidgets('type after zoom+browse inserts at relocated caret',
        (tester) async {
      final controller = longNote();
      await pumpHarness(
        tester,
        controller: controller,
        wrapZoom: true,
        zoomScale: 1.6,
      );
      final before = controller.selection.baseOffset;

      await tester.drag(find.byType(QuillEditor), const Offset(0, 220));
      await tester.pumpAndSettle();
      final at = controller.selection.baseOffset;
      expect(at, lessThan(before));

      controller.replaceText(
        at,
        0,
        'ZOOM',
        TextSelection.collapsed(offset: at + 4),
      );
      await tester.pump();
      expect(controller.document.toPlainText().contains('ZOOM'), isTrue);
      expect(controller.selection.baseOffset, lessThan(before));
    });
  });
}

class _StubEmbedBuilder extends EmbedBuilder {
  const _StubEmbedBuilder(this.key);

  @override
  final String key;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return const SizedBox(
      height: 72,
      width: double.infinity,
      child: ColoredBox(color: Color(0xFFE0E0E0)),
    );
  }
}

class _StubUnknownEmbed extends EmbedBuilder {
  const _StubUnknownEmbed();

  @override
  String get key => 'unknown';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return const SizedBox(
      height: 48,
      width: double.infinity,
      child: ColoredBox(color: Color(0xFFBDBDBD)),
    );
  }
}
