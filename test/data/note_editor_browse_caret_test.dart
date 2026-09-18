import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/features/notes/presentation/note_editor_browse_caret_sync.dart';

void main() {
  QuillController longController({int paragraphs = 80, int caretAt = -1}) {
    final controller = QuillController(
      document: Document.fromJson([
        {
          'insert': List.generate(
            paragraphs,
            (i) => 'Paragraph $i of sample note.\n',
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

  Future<({NoteEditorBrowseCaretSync sync, ScrollController scroll})>
      pumpEditor(
    WidgetTester tester, {
    required QuillController controller,
    double minBrowseDistance = 20,
    double height = 320,
  }) async {
    final hostKey = GlobalKey();
    final scrollController = ScrollController();
    final sync = NoteEditorBrowseCaretSync(
      controller: controller,
      editorHostKey: hostKey,
      scrollController: scrollController,
      minBrowseDistance: minBrowseDistance,
    );
    addTearDown(() {
      sync.dispose();
      scrollController.dispose();
      controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: height,
            child: KeyedSubtree(
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
    );
    await tester.pumpAndSettle();
    return (sync: sync, scroll: scrollController);
  }

  group('safeBrowseCaretOffset', () {
    test('leaves plain text offsets unchanged', () {
      final doc = Document.fromJson([
        {'insert': 'Hello\n'},
      ]);
      expect(safeBrowseCaretOffset(doc, 2), 2);
    });

    test('nudges past a single embed onto following text', () {
      final doc = Document.fromJson([
        {
          'insert': {'image': 'images/a.png'},
        },
        {'insert': '\nAfter\n'},
      ]);
      // Offset 0 is the embed object-replacement char.
      final nudged = safeBrowseCaretOffset(doc, 0);
      expect(nudged, greaterThan(0));
      final leaf = doc.querySegmentLeafNode(nudged).leaf;
      expect(leaf, isNot(isA<Embed>()));
    });

    test('nudges past consecutive embeds', () {
      final doc = Document.fromJson([
        {
          'insert': {'image': 'images/a.png'},
        },
        {'insert': '\n'},
        {
          'insert': {'image': 'images/b.png'},
        },
        {'insert': '\nTail\n'},
      ]);
      final nudged = safeBrowseCaretOffset(doc, 0);
      final leaf = doc.querySegmentLeafNode(nudged).leaf;
      expect(leaf, isNot(isA<Embed>()));
      expect(doc.toPlainText().substring(nudged).contains('Tail'), isTrue);
    });
  });

  testWidgets(
    'user drag scroll relocates caret into the visible band',
    (tester) async {
      final controller = longController();
      await pumpEditor(tester, controller: controller);

      final before = controller.selection.baseOffset;
      expect(before, controller.document.length - 1);

      await tester.drag(find.byType(QuillEditor), const Offset(0, 220));
      await tester.pumpAndSettle();

      final after = controller.selection.baseOffset;
      expect(
        after,
        lessThan(before),
        reason: 'Caret should move into the browsed (earlier) region',
      );
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.skipRequestKeyboard, isFalse);
    },
  );

  testWidgets(
    'browse distance below threshold does not relocate the caret',
    (tester) async {
      final controller = longController(paragraphs: 40, caretAt: 12);
      final pumped = await pumpEditor(
        tester,
        controller: controller,
        minBrowseDistance: 80,
        height: 280,
      );
      final sync = pumped.sync;

      final ctx = tester.element(find.byType(QuillEditor));
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: 40,
        viewportDimension: 280,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );
      sync.onScrollNotification(
        ScrollUpdateNotification(
          metrics: metrics,
          context: ctx,
          scrollDelta: 24,
          dragDetails: DragUpdateDetails(
            globalPosition: Offset.zero,
            delta: const Offset(0, 24),
            primaryDelta: 24,
          ),
        ),
      );
      sync.onScrollNotification(
        ScrollEndNotification(metrics: metrics, context: ctx),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection.baseOffset, 12);
    },
  );

  testWidgets(
    'ballistic scroll without drag does not relocate the caret',
    (tester) async {
      final controller = longController(caretAt: 40);
      final sync = (await pumpEditor(tester, controller: controller)).sync;
      final ctx = tester.element(find.byType(QuillEditor));
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: 400,
        viewportDimension: 320,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );

      sync.onScrollNotification(
        ScrollUpdateNotification(
          metrics: metrics,
          context: ctx,
          scrollDelta: 120,
        ),
      );
      sync.onScrollNotification(
        ScrollEndNotification(metrics: metrics, context: ctx),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection.baseOffset, 40);
    },
  );

  testWidgets(
    'short non-scrollable note does not relocate caret on overscroll',
    (tester) async {
      final controller = QuillController(
        document: Document.fromJson([
          {'insert': 'Short note\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 0),
      );
      final sync = (await pumpEditor(
        tester,
        controller: controller,
        minBrowseDistance: 20,
        height: 320,
      ))
          .sync;
      final ctx = tester.element(find.byType(QuillEditor));
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 0,
        pixels: -30,
        viewportDimension: 320,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );

      sync.onScrollNotification(
        ScrollUpdateNotification(
          metrics: metrics,
          context: ctx,
          scrollDelta: 40,
          dragDetails: DragUpdateDetails(
            globalPosition: Offset.zero,
            delta: const Offset(0, 40),
            primaryDelta: 40,
          ),
        ),
      );
      sync.onScrollNotification(
        ScrollEndNotification(metrics: metrics, context: ctx),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection.baseOffset, 0);
    },
  );

  testWidgets(
    'expanded selection is preserved after browse scroll end',
    (tester) async {
      final controller = longController(caretAt: 10);
      controller.updateSelection(
        const TextSelection(baseOffset: 10, extentOffset: 24),
        ChangeSource.local,
      );
      final sync = (await pumpEditor(tester, controller: controller)).sync;
      final ctx = tester.element(find.byType(QuillEditor));
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: 300,
        viewportDimension: 320,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );

      sync.onScrollNotification(
        ScrollUpdateNotification(
          metrics: metrics,
          context: ctx,
          scrollDelta: 80,
          dragDetails: DragUpdateDetails(
            globalPosition: Offset.zero,
            delta: const Offset(0, 80),
            primaryDelta: 80,
          ),
        ),
      );
      sync.onScrollNotification(
        ScrollEndNotification(metrics: metrics, context: ctx),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection.baseOffset, 10);
      expect(controller.selection.extentOffset, 24);
      expect(controller.selection.isCollapsed, isFalse);
    },
  );

  testWidgets(
    'typing after browse drag inserts at the relocated caret',
    (tester) async {
      final controller = longController();
      await pumpEditor(tester, controller: controller);

      final before = controller.selection.baseOffset;
      await tester.drag(find.byType(QuillEditor), const Offset(0, 220));
      await tester.pumpAndSettle();

      final at = controller.selection.baseOffset;
      expect(at, lessThan(before));

      controller.replaceText(
        at,
        0,
        'XYZ',
        TextSelection.collapsed(offset: at + 3),
      );
      await tester.pump();

      final plain = controller.document.toPlainText();
      expect(plain.contains('XYZ'), isTrue);
      expect(controller.selection.baseOffset, at + 3);
    },
  );

  testWidgets(
    'wheel ticks accumulate across ScrollEnd and relocate after settle',
    (tester) async {
      final controller = longController();
      final pumped = await pumpEditor(
        tester,
        controller: controller,
        minBrowseDistance: 36,
      );
      final sync = pumped.sync;
      final before = controller.selection.baseOffset;

      final ctx = tester.element(find.byType(QuillEditor));
      // Jump content so the visible band is earlier text once caret moves.
      if (pumped.scroll.hasClients) {
        await pumped.scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 1),
          curve: Curves.linear,
        );
        await tester.pumpAndSettle();
      }

      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: 0,
        viewportDimension: 320,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );

      // Simulate Flutter pointerScroll: each tick ends with ScrollEnd and
      // has no dragDetails. Distance must accumulate across ticks.
      for (var i = 0; i < 3; i++) {
        sync.onPointerScroll(
          const PointerScrollEvent(scrollDelta: Offset(0, 20)),
        );
        sync.onScrollNotification(
          ScrollUpdateNotification(
            metrics: metrics,
            context: ctx,
            scrollDelta: 20,
          ),
        );
        sync.onScrollNotification(
          ScrollEndNotification(metrics: metrics, context: ctx),
        );
      }

      // Below settle window: caret should still be at the old place.
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.selection.baseOffset, before);

      // After wheel settle debounce, caret relocates into the visible band.
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        controller.selection.baseOffset,
        lessThan(before),
        reason: 'Wheel browse should relocate after settle, despite per-tick ScrollEnd',
      );
      expect(controller.skipRequestKeyboard, isFalse);
    },
  );

  testWidgets(
    'dispose cancels pending wheel settle without throwing',
    (tester) async {
      final controller = longController(caretAt: 20);
      final hostKey = GlobalKey();
      final scrollController = ScrollController();
      final sync = NoteEditorBrowseCaretSync(
        controller: controller,
        editorHostKey: hostKey,
        scrollController: scrollController,
        minBrowseDistance: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: KeyedSubtree(
                key: hostKey,
                child: QuillEditor.basic(
                  controller: controller,
                  scrollController: scrollController,
                  config: const QuillEditorConfig(
                    scrollable: true,
                    expands: false,
                    autoFocus: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      sync.onPointerScroll(
        const PointerScrollEvent(scrollDelta: Offset(0, 40)),
      );
      sync.dispose();
      scrollController.dispose();
      controller.dispose();

      await tester.pump(const Duration(milliseconds: 200));
      // No throw; caret placement must not run after dispose.
    },
  );

  testWidgets(
    'readOnly controller does not relocate caret on browse',
    (tester) async {
      final controller = longController();
      controller.readOnly = true;
      final sync = (await pumpEditor(tester, controller: controller)).sync;
      final before = controller.selection.baseOffset;
      final ctx = tester.element(find.byType(QuillEditor));
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: 200,
        viewportDimension: 320,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );

      sync.onScrollNotification(
        ScrollUpdateNotification(
          metrics: metrics,
          context: ctx,
          scrollDelta: 100,
          dragDetails: DragUpdateDetails(
            globalPosition: Offset.zero,
            delta: const Offset(0, 100),
            primaryDelta: 100,
          ),
        ),
      );
      sync.onScrollNotification(
        ScrollEndNotification(metrics: metrics, context: ctx),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.selection.baseOffset, before);
    },
  );
}
