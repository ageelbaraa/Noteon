import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noteon/features/notes/presentation/note_editor_browse_caret_sync.dart';

/// Device-oriented browse/caret scenarios for Noteon.
///
/// These intentionally use a Quill harness (not the full Isar-backed app) so
/// Firebase Test Lab validates scroll/caret behavior without depending on
/// local DB state. Full-app smoke lives in `app_smoke_test.dart`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  QuillController longNote({int paragraphs = 60, int caretAt = -1}) {
    final controller = QuillController(
      document: Document.fromJson([
        {
          'insert': List.generate(
            paragraphs,
            (i) => 'Paragraph $i of sample note for browse testing.\n',
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

  Future<NoteEditorBrowseCaretSync> pumpHarness(
    WidgetTester tester, {
    required QuillController controller,
    double minBrowseDistance = 24,
    double height = 480,
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
            width: 360,
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
    return sync;
  }

  testWidgets('FTL: long note drag-browse relocates caret', (tester) async {
    final controller = longNote();
    await pumpHarness(tester, controller: controller);
    final before = controller.selection.baseOffset;

    await tester.drag(find.byType(QuillEditor), const Offset(0, 260));
    await tester.pumpAndSettle();

    expect(controller.selection.baseOffset, lessThan(before));
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.skipRequestKeyboard, isFalse);
  });

  testWidgets('FTL: typing after browse inserts at new caret', (tester) async {
    final controller = longNote();
    await pumpHarness(tester, controller: controller);
    final before = controller.selection.baseOffset;

    await tester.drag(find.byType(QuillEditor), const Offset(0, 260));
    await tester.pumpAndSettle();
    final at = controller.selection.baseOffset;
    expect(at, lessThan(before));

    controller.replaceText(
      at,
      0,
      'HELLO',
      TextSelection.collapsed(offset: at + 5),
    );
    await tester.pump();
    expect(controller.document.toPlainText().contains('HELLO'), isTrue);
  });

  testWidgets('FTL: expanded selection survives browse end', (tester) async {
    final controller = longNote(caretAt: 20);
    controller.updateSelection(
      const TextSelection(baseOffset: 20, extentOffset: 40),
      ChangeSource.local,
    );
    final sync = await pumpHarness(tester, controller: controller);
    final ctx = tester.element(find.byType(QuillEditor));
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 3000,
      pixels: 400,
      viewportDimension: 480,
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
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.selection.baseOffset, 20);
    expect(controller.selection.extentOffset, 40);
  });

  testWidgets('FTL: short note overscroll does not move caret', (tester) async {
    final controller = QuillController(
      document: Document.fromJson([
        {'insert': 'Short\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );
    final sync = await pumpHarness(
      tester,
      controller: controller,
      minBrowseDistance: 20,
    );
    final ctx = tester.element(find.byType(QuillEditor));
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 0,
      pixels: -20,
      viewportDimension: 480,
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
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.selection.baseOffset, 0);
  });

  testWidgets('FTL: caret nudged off embed object', (tester) async {
    final doc = Document.fromJson([
      {
        'insert': {'image': 'images/demo.png'},
      },
      {'insert': '\nAfter drawing\n'},
    ]);
    final offset = safeBrowseCaretOffset(doc, 0);
    final leaf = doc.querySegmentLeafNode(offset).leaf;
    expect(leaf, isNot(isA<Embed>()));
    expect(doc.toPlainText().substring(offset).contains('After'), isTrue);
  });

  testWidgets('FTL: wheel ticks accumulate despite ScrollEnd', (tester) async {
    final controller = longNote();
    final sync = await pumpHarness(
      tester,
      controller: controller,
      minBrowseDistance: 36,
    );
    final before = controller.selection.baseOffset;
    final ctx = tester.element(find.byType(QuillEditor));
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 3000,
      pixels: 0,
      viewportDimension: 480,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

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
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.selection.baseOffset, before);
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.selection.baseOffset, lessThan(before));
  });
}
