import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/features/notes/presentation/note_editor_browse_caret_sync.dart';

/// Widget-level reproduction of committed InteractiveViewer hit-miss (issue B).
///
/// Mirrors HEAD `NoteEditorZoomViewport`: InteractiveViewer + SizedBox.expand +
/// Quill. Demonstrates failure before any production fix.
void main() {
  QuillController longNote() {
    final c = QuillController(
      document: Document.fromJson([
        {
          'insert': List.generate(
            60,
            (i) => 'Paragraph $i for hit-miss reproduction.\n',
          ).join(),
        },
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );
    c.updateSelection(
      TextSelection.collapsed(offset: c.document.length - 1),
      ChangeSource.local,
    );
    return c;
  }

  Future<
      ({
        TransformationController transform,
        ValueNotifier<int> dragScrolls,
      })> pumpIv(
    WidgetTester tester, {
    required QuillController controller,
    required bool panEnabled,
  }) async {
    final hostKey = GlobalKey();
    final transform = TransformationController();
    final scroll = ScrollController();
    final focus = FocusNode();
    final dragScrolls = ValueNotifier<int>(0);
    final sync = NoteEditorBrowseCaretSync(
      controller: controller,
      editorHostKey: hostKey,
      scrollController: scroll,
    );
    addTearDown(() {
      sync.dispose();
      scroll.dispose();
      focus.dispose();
      controller.dispose();
      transform.dispose();
      dragScrolls.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 400,
              child: InteractiveViewer(
                transformationController: transform,
                minScale: 1,
                maxScale: 3.5,
                panEnabled: panEnabled,
                scaleEnabled: true,
                clipBehavior: Clip.hardEdge,
                boundaryMargin: const EdgeInsets.all(48),
                child: SizedBox.expand(
                  child: KeyedSubtree(
                    key: hostKey,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollUpdateNotification &&
                            n.dragDetails != null) {
                          dragScrolls.value++;
                        }
                        return sync.onScrollNotification(n);
                      },
                      child: QuillEditor.basic(
                        controller: controller,
                        focusNode: focus,
                        scrollController: scroll,
                        config: const QuillEditorConfig(
                          scrollable: true,
                          expands: false,
                          autoFocus: false,
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
    );
    await tester.pumpAndSettle();
    return (transform: transform, dragScrolls: dragScrolls);
  }

  void applyZoomPan(
    TransformationController t, {
    required double scale,
    Offset translation = Offset.zero,
  }) {
    const viewport = Size(360, 400);
    final focal = Offset(viewport.width / 2, viewport.height / 2);
    final scene = Offset(focal.dx - translation.dx, focal.dy - translation.dy);
    t.value = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  ({bool hitEditor, bool sceneInChild, Offset scene, List<String> path}) probe(
    WidgetTester tester,
    TransformationController transform,
    Offset local,
  ) {
    final box =
        tester.renderObject(find.byType(InteractiveViewer).first) as RenderBox;
    final result = BoxHitTestResult();
    box.hitTest(result, position: local);
    var hitEditor = false;
    final path = <String>[];
    for (final e in result.path) {
      path.add(e.target.runtimeType.toString());
      if (e.target is RenderEditor) {
        hitEditor = true;
      }
    }
    final scene = transform.toScene(local);
    final sceneInChild =
        scene.dx >= 0 && scene.dx <= 360 && scene.dy >= 0 && scene.dy <= 400;
    return (
      hitEditor: hitEditor,
      sceneInChild: sceneInChild,
      scene: scene,
      path: path,
    );
  }

  testWidgets('1× center hits RenderEditor', (tester) async {
    final controller = longNote();
    final h = await pumpIv(tester, controller: controller, panEnabled: false);
    final p = probe(tester, h.transform, const Offset(180, 200));
    expect(p.hitEditor, isTrue);
    expect(p.sceneInChild, isTrue);
  });

  testWidgets('2.4× no pan: center and edges hit RenderEditor', (tester) async {
    final controller = longNote();
    final h = await pumpIv(tester, controller: controller, panEnabled: true);
    applyZoomPan(h.transform, scale: 2.4);
    await tester.pumpAndSettle();

    for (final local in const [
      Offset(180, 200),
      Offset(180, 40),
      Offset(180, 360),
      Offset(40, 200),
      Offset(320, 200),
    ]) {
      final p = probe(tester, h.transform, local);
      expect(p.hitEditor, isTrue, reason: 'local=$local scene=${p.scene}');
      expect(p.sceneInChild, isTrue, reason: 'local=$local');
    }
  });

  /// Scene-space viewport at scale S is (360/S)×(400/S). With
  /// boundaryMargin 48, IV allows that rect to sit partly above y=0, so the
  /// top of the clip maps outside the child layout box while lower pixels
  /// still show editor content.
  Matrix4 matrixForSceneViewportTop(double scale, double sceneTop) {
    const vw = 360.0;
    const vh = 400.0;
    final sceneH = vh / scale;
    final sceneCenter = Offset(vw / 2, sceneTop + sceneH / 2);
    final focal = const Offset(vw / 2, vh / 2);
    return Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-sceneCenter.dx, -sceneCenter.dy, 0, 1);
  }

  testWidgets(
    'REPRO: 2.4× + boundaryMargin pan → top misses, mid still hits',
    (tester) async {
      final controller = longNote();
      final h = await pumpIv(tester, controller: controller, panEnabled: true);
      // Legal-ish: sceneTop = -40 is within margin 48, straddles child edge.
      h.transform.value = matrixForSceneViewportTop(2.4, -40);
      await tester.pumpAndSettle();

      final top = probe(tester, h.transform, const Offset(180, 40));
      final mid = probe(tester, h.transform, const Offset(180, 200));
      final bottom = probe(tester, h.transform, const Offset(180, 360));

      debugPrint(
        'HIT_MISS_REPRO topHit=${top.hitEditor} topScene=${top.scene} '
        'midHit=${mid.hitEditor} midScene=${mid.scene} '
        'bottomHit=${bottom.hitEditor} bottomScene=${bottom.scene} '
        'topPath=${top.path.take(6).join(">")}',
      );

      expect(top.sceneInChild, isFalse);
      expect(top.hitEditor, isFalse);
      expect(mid.sceneInChild, isTrue);
      expect(mid.hitEditor, isTrue);
      expect(bottom.hitEditor, isTrue);
      expect(
        top.path.any((s) => s.contains('PointerListener')),
        isTrue,
      );
    },
  );

  testWidgets(
    'CONTROL: same pan with boundaryMargin zero keeps all samples hittable',
    (tester) async {
      // Rebuild without margin — mirrors candidate Option A.
      final hostKey = GlobalKey();
      final transform = TransformationController();
      final scroll = ScrollController();
      final focus = FocusNode();
      final controller = longNote();
      addTearDown(() {
        scroll.dispose();
        focus.dispose();
        controller.dispose();
        transform.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 400,
                child: InteractiveViewer(
                  transformationController: transform,
                  minScale: 1,
                  maxScale: 3.5,
                  panEnabled: true,
                  clipBehavior: Clip.hardEdge,
                  boundaryMargin: EdgeInsets.zero,
                  child: SizedBox.expand(
                    child: KeyedSubtree(
                      key: hostKey,
                      child: QuillEditor.basic(
                        controller: controller,
                        focusNode: focus,
                        scrollController: scroll,
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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Force the straddling matrix anyway; with zero margin production would
      // clamp, but even this matrix's in-child samples must hit.
      transform.value = matrixForSceneViewportTop(2.4, 0);
      await tester.pump();

      for (final local in const [
        Offset(180, 40),
        Offset(180, 200),
        Offset(180, 360),
      ]) {
        final p = probe(tester, transform, local);
        expect(p.sceneInChild, isTrue, reason: '$local ${p.scene}');
        expect(p.hitEditor, isTrue, reason: '$local');
      }
    },
  );

  testWidgets(
    'REPRO: miss region one-finger drag does not arm Quill browse',
    (tester) async {
      final controller = longNote();
      final h = await pumpIv(tester, controller: controller, panEnabled: true);
      h.transform.value = matrixForSceneViewportTop(2.4, -40);
      await tester.pumpAndSettle();

      final box =
          tester.renderObject(find.byType(InteractiveViewer).first) as RenderBox;
      final global = box.localToGlobal(const Offset(180, 40));
      final before = controller.selection.baseOffset;
      final g = await tester.startGesture(global);
      await g.moveBy(const Offset(0, 200));
      await tester.pump(const Duration(milliseconds: 40));
      await g.up();
      await tester.pumpAndSettle();

      expect(h.dragScrolls.value, 0);
      // Caret should not relocate via browse (no dragDetails scroll).
      expect(controller.selection.baseOffset, before);
    },
  );

  testWidgets(
    'BASELINE: finder drag on Quill still browses when editor is hittable',
    (tester) async {
      final controller = longNote();
      final h = await pumpIv(tester, controller: controller, panEnabled: false);
      final before = controller.selection.baseOffset;
      await tester.drag(find.byType(QuillEditor), const Offset(0, 220));
      await tester.pumpAndSettle();
      expect(h.dragScrolls.value, greaterThan(0));
      expect(controller.selection.baseOffset, lessThan(before));
    },
  );

  testWidgets('matrix: scene-in-child predicts hitEditor across pan grid',
      (tester) async {
    final controller = longNote();
    final h = await pumpIv(tester, controller: controller, panEnabled: true);

    final cases = <(double scale, Offset pan, Offset local)>[
      (1.0, Offset.zero, const Offset(180, 200)),
      (1.5, Offset.zero, const Offset(180, 40)),
      (2.4, Offset.zero, const Offset(180, 40)),
      (2.4, const Offset(0, 100), const Offset(180, 40)),
      (2.4, const Offset(0, 220), const Offset(180, 40)),
      (2.4, const Offset(0, 220), const Offset(180, 200)),
      (2.4, const Offset(180, 0), const Offset(40, 200)),
      (2.4, const Offset(180, 180), const Offset(40, 40)),
    ];

    for (final (scale, pan, local) in cases) {
      applyZoomPan(h.transform, scale: scale, translation: pan);
      await tester.pump();
      final p = probe(tester, h.transform, local);
      expect(
        p.hitEditor,
        p.sceneInChild,
        reason:
            'scale=$scale pan=$pan local=$local scene=${p.scene} '
            'path=${p.path.take(5).join(">")}',
      );
    }
  });
}
