import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noteon/features/notes/presentation/note_editor_browse_caret_sync.dart';

/// Investigation B — gesture reachability under zoom/pan (no production edits).
///
/// **Committed production** (`main`) uses [InteractiveViewer] inside
/// `NoteEditorZoomViewport` with `panEnabled` only when scale > 1.02.
///
/// Local worktree currently has an *uncommitted* Listener+Transform rewrite;
/// this suite mirrors the **committed InteractiveViewer** path that CI builds.
///
/// Soft assertions only — prints `HIT_INV[...]` evidence lines.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  QuillController longNote({int paragraphs = 70}) {
    final controller = QuillController(
      document: Document.fromJson([
        {
          'insert': List.generate(
            paragraphs,
            (i) => 'Paragraph $i hit-test investigation content.\n',
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

  /// Mirrors committed `NoteEditorZoomViewport` (InteractiveViewer).
  Future<
      ({
        GlobalKey hostKey,
        TransformationController transform,
        NoteEditorBrowseCaretSync sync,
        ValueNotifier<int> dragScrolls,
        ValueNotifier<int> anyScrolls,
        ValueNotifier<double> browseArmed,
      })> pumpInteractiveViewerStack(
    WidgetTester tester, {
    required QuillController controller,
    bool panEnabled = false,
    double minScale = 1,
    double maxScale = 3.5,
    double height = 400,
    double width = 360,
  }) async {
    final hostKey = GlobalKey();
    final transform = TransformationController();
    final scrollController = ScrollController();
    final focusNode = FocusNode();
    final dragScrolls = ValueNotifier<int>(0);
    final anyScrolls = ValueNotifier<int>(0);
    final browseArmed = ValueNotifier<double>(0);
    final sync = NoteEditorBrowseCaretSync(
      controller: controller,
      editorHostKey: hostKey,
      scrollController: scrollController,
      minBrowseDistance: 24,
    );
    addTearDown(() {
      sync.dispose();
      scrollController.dispose();
      focusNode.dispose();
      controller.dispose();
      transform.dispose();
      dragScrolls.dispose();
      anyScrolls.dispose();
      browseArmed.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: height,
            width: width,
            child: InteractiveViewer(
              transformationController: transform,
              minScale: minScale,
              maxScale: maxScale,
              panEnabled: panEnabled,
              scaleEnabled: true,
              trackpadScrollCausesScale: false,
              clipBehavior: Clip.hardEdge,
              boundaryMargin: const EdgeInsets.all(48),
              child: SizedBox.expand(
                child: KeyedSubtree(
                  key: hostKey,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      anyScrolls.value++;
                      if (n is ScrollUpdateNotification &&
                          n.dragDetails != null) {
                        dragScrolls.value++;
                        browseArmed.value += n.scrollDelta?.abs() ?? 0;
                      }
                      return sync.onScrollNotification(n);
                    },
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
    );
    await tester.pumpAndSettle();
    return (
      hostKey: hostKey,
      transform: transform,
      sync: sync,
      dragScrolls: dragScrolls,
      anyScrolls: anyScrolls,
      browseArmed: browseArmed,
    );
  }

  void applyZoomPan(
    TransformationController transform, {
    required double scale,
    Offset translation = Offset.zero,
    Size viewport = const Size(360, 400),
  }) {
    final focal = Offset(viewport.width / 2, viewport.height / 2);
    final scene = Offset(focal.dx - translation.dx, focal.dy - translation.dy);
    transform.value = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  ({bool hitEditor, List<String> path}) probeHit(
    WidgetTester tester,
    Offset localInViewer,
  ) {
    final viewer = tester.renderObject(find.byType(InteractiveViewer).first);
    final box = viewer as RenderBox;
    final result = BoxHitTestResult();
    box.hitTest(result, position: localInViewer);
    var hitEditor = false;
    final path = <String>[];
    for (final entry in result.path) {
      final name = entry.target.runtimeType.toString();
      path.add(name);
      if (entry.target is RenderEditor) {
        hitEditor = true;
      }
    }
    return (hitEditor: hitEditor, path: path);
  }

  Future<void> oneFingerDrag(
    WidgetTester tester,
    Offset localInViewer, {
    Offset delta = const Offset(0, 200),
  }) async {
    final box =
        tester.renderObject(find.byType(InteractiveViewer).first) as RenderBox;
    final global = box.localToGlobal(localInViewer);
    final g = await tester.startGesture(global);
    await g.moveBy(delta);
    await tester.pump(const Duration(milliseconds: 40));
    await g.up();
    await tester.pumpAndSettle();
  }

  void logCase({
    required String label,
    required double scale,
    required bool panEnabled,
    required Offset pan,
    required Offset local,
    required bool hitEditor,
    required int dragScrolls,
    required double browseArmed,
    required int caretBefore,
    required int caretAfter,
    required List<String> path,
  }) {
    final relocated = caretAfter != caretBefore;
    debugPrint(
      'HIT_INV[$label] scale=$scale panEnabled=$panEnabled pan=$pan '
      'local=$local hitEditor=$hitEditor dragScrolls=$dragScrolls '
      'browseArmed=${browseArmed.toStringAsFixed(1)} '
      'caretBefore=$caretBefore caretAfter=$caretAfter relocated=$relocated '
      'path=${path.take(10).join(">")}',
    );
  }

  group('Event path documentation (committed InteractiveViewer)', () {
    testWidgets('prints structural path notes', (tester) async {
      // Structural knowledge recorded as a passing probe.
      debugPrint(
        'HIT_INV[path_doc] '
        'Clip/IV: InteractiveViewer(clipBehavior=hardEdge) → '
        'SizedBox.expand → NotificationListener(browse) → QuillEditor. '
        'At 1× panEnabled=false so IV should not claim one-finger pan. '
        'When zoomed panEnabled=true IV competes with Quill vertical drag '
        'in the gesture arena for one-finger movement.',
      );
      expect(true, isTrue);
    });
  });

  group('B: InteractiveViewer panEnabled vs Quill drag (committed model)', () {
    testWidgets('1× panEnabled=false: QuillEditor.drag vs clip-local drag',
        (tester) async {
      final controller = longNote();
      final h = await pumpInteractiveViewerStack(
        tester,
        controller: controller,
        panEnabled: false,
      );
      applyZoomPan(h.transform, scale: 1.0);
      await tester.pumpAndSettle();

      // A) Canonical finder drag (matches existing browse IT).
      h.dragScrolls.value = 0;
      var before = controller.selection.baseOffset;
      await tester.drag(find.byType(QuillEditor), const Offset(0, 220));
      await tester.pumpAndSettle();
      debugPrint(
        'HIT_INV[1x_finder_drag] dragScrolls=${h.dragScrolls.value} '
        'relocated=${controller.selection.baseOffset != before} '
        'before=$before after=${controller.selection.baseOffset}',
      );
      final finderWorked = h.dragScrolls.value > 0;

      // Reset caret to EOF for second probe.
      controller.updateSelection(
        TextSelection.collapsed(offset: controller.document.length - 1),
        ChangeSource.local,
      );
      await tester.pump();

      // B) Clip-local startGesture (visible-viewport center).
      h.dragScrolls.value = 0;
      before = controller.selection.baseOffset;
      final hit = probeHit(tester, const Offset(180, 200));
      await oneFingerDrag(tester, const Offset(180, 200));
      debugPrint(
        'HIT_INV[1x_clip_local_drag] hitEditor=${hit.hitEditor} '
        'dragScrolls=${h.dragScrolls.value} '
        'relocated=${controller.selection.baseOffset != before}',
      );

      expect(finderWorked, isTrue);
      // Clip-local probes can miss after transform/scroll; log only.
      debugPrint(
        'HIT_INV[1x_compare] finderWorked=$finderWorked '
        'clipLocalHitEditor=${hit.hitEditor} '
        'clipLocalDrags=${h.dragScrolls.value}',
      );
    });

    testWidgets(
        'zoomed panEnabled=true: QuillEditor.drag vs clip-local (arena)',
        (tester) async {
      for (final scale in [1.5, 2.4]) {
        final controller = longNote();
        final h = await pumpInteractiveViewerStack(
          tester,
          controller: controller,
          panEnabled: true,
        );
        applyZoomPan(h.transform, scale: scale);
        await tester.pumpAndSettle();

        h.dragScrolls.value = 0;
        var before = controller.selection.baseOffset;
        await tester.drag(
          find.byType(QuillEditor),
          const Offset(0, 220),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        final finderDrags = h.dragScrolls.value;
        final finderRelocated = controller.selection.baseOffset != before;

        controller.updateSelection(
          TextSelection.collapsed(offset: controller.document.length - 1),
          ChangeSource.local,
        );
        await tester.pump();

        h.dragScrolls.value = 0;
        before = controller.selection.baseOffset;
        final hit = probeHit(tester, const Offset(180, 200));
        await oneFingerDrag(tester, const Offset(180, 200));
        debugPrint(
          'HIT_INV[zoom_arena s=$scale] hitEditor=${hit.hitEditor} '
          'finderDrags=$finderDrags finderRelocated=$finderRelocated '
          'clipLocalDrags=${h.dragScrolls.value} '
          'clipLocalRelocated=${controller.selection.baseOffset != before}',
        );
      }
      expect(true, isTrue);
    });

    testWidgets(
        'zoomed panEnabled=true no pan: one-finger drag may be stolen by IV',
        (tester) async {
      final rows = <Map<String, Object?>>[];
      for (final scale in [1.5, 2.0, 2.4, 3.0]) {
        final controller = longNote();
        final h = await pumpInteractiveViewerStack(
          tester,
          controller: controller,
          panEnabled: true, // production when scale > 1.02
        );
        applyZoomPan(h.transform, scale: scale);
        await tester.pumpAndSettle();

        const local = Offset(180, 200);
        final hit = probeHit(tester, local);
        final before = controller.selection.baseOffset;
        h.dragScrolls.value = 0;
        h.browseArmed.value = 0;
        await oneFingerDrag(tester, local, delta: const Offset(0, 220));

        final after = controller.selection.baseOffset;
        logCase(
          label: 'zoom_${scale}_nopan_panEnabled',
          scale: scale,
          panEnabled: true,
          pan: Offset.zero,
          local: local,
          hitEditor: hit.hitEditor,
          dragScrolls: h.dragScrolls.value,
          browseArmed: h.browseArmed.value,
          caretBefore: before,
          caretAfter: after,
          path: hit.path,
        );
        rows.add({
          'scale': scale,
          'hitEditor': hit.hitEditor,
          'dragScrolls': h.dragScrolls.value,
          'relocated': after != before,
        });
      }
      debugPrint('HIT_INV[zoom_nopan_table] $rows');
      expect(rows, isNotEmpty);
    });

    testWidgets('zoomed + pan offsets: center/edges drag reachability',
        (tester) async {
      final locations = <Offset>[
        const Offset(180, 200), // center
        const Offset(180, 40), // top
        const Offset(180, 360), // bottom
        const Offset(40, 200), // left
        const Offset(320, 200), // right
      ];
      final pans = <Offset>[
        Offset.zero,
        const Offset(0, 180),
        const Offset(140, 0),
        const Offset(100, 160),
        const Offset(0, 280),
      ];

      for (final scale in [2.0, 2.4]) {
        for (final pan in pans) {
          for (final local in locations) {
            final controller = longNote();
            final h = await pumpInteractiveViewerStack(
              tester,
              controller: controller,
              panEnabled: true,
            );
            applyZoomPan(h.transform, scale: scale, translation: pan);
            await tester.pumpAndSettle();

            final hit = probeHit(tester, local);
            final before = controller.selection.baseOffset;
            h.dragScrolls.value = 0;
            await oneFingerDrag(tester, local, delta: const Offset(0, 180));

            logCase(
              label: 'matrix_s${scale}_pan${pan.dx.toInt()}_${pan.dy.toInt()}'
                  '_x${local.dx.toInt()}_y${local.dy.toInt()}',
              scale: scale,
              panEnabled: true,
              pan: pan,
              local: local,
              hitEditor: hit.hitEditor,
              dragScrolls: h.dragScrolls.value,
              browseArmed: h.browseArmed.value,
              caretBefore: before,
              caretAfter: controller.selection.baseOffset,
              path: hit.path,
            );
          }
        }
      }
      expect(true, isTrue);
    });

    testWidgets(
        'control: zoomed but panEnabled=false still delivers Quill drag',
        (tester) async {
      // Isolates arena ownership: same transform, pan disabled.
      final controller = longNote();
      final h = await pumpInteractiveViewerStack(
        tester,
        controller: controller,
        panEnabled: false,
      );
      applyZoomPan(h.transform, scale: 2.4, translation: const Offset(0, 200));
      await tester.pumpAndSettle();

      const local = Offset(180, 200);
      final hit = probeHit(tester, local);
      final before = controller.selection.baseOffset;
      await oneFingerDrag(tester, local);

      logCase(
        label: 'control_zoom_panEnabled_false',
        scale: 2.4,
        panEnabled: false,
        pan: const Offset(0, 200),
        local: local,
        hitEditor: hit.hitEditor,
        dragScrolls: h.dragScrolls.value,
        browseArmed: h.browseArmed.value,
        caretBefore: before,
        caretAfter: controller.selection.baseOffset,
        path: hit.path,
      );

      // If this still gets dragScrolls while panEnabled=true cases do not,
      // the root cause is IV gesture ownership — not Transform miss.
      debugPrint(
        'HIT_INV[control_verdict] hitEditor=${hit.hitEditor} '
        'dragScrolls=${h.dragScrolls.value} '
        '(compare to panEnabled=true cases)',
      );
      expect(controller.selection.isCollapsed, isTrue);
    });

    testWidgets('short/normal/long drag at 1× vs zoomed panEnabled',
        (tester) async {
      for (final cfg in [
        (scale: 1.0, panEnabled: false, name: '1x'),
        (scale: 2.4, panEnabled: true, name: 'z2.4_panOn'),
      ]) {
        for (final dy in [24.0, 80.0, 220.0]) {
          final controller = longNote();
          final h = await pumpInteractiveViewerStack(
            tester,
            controller: controller,
            panEnabled: cfg.panEnabled,
          );
          applyZoomPan(h.transform, scale: cfg.scale);
          await tester.pumpAndSettle();
          final before = controller.selection.baseOffset;
          await oneFingerDrag(
            tester,
            const Offset(180, 200),
            delta: Offset(0, dy),
          );
          debugPrint(
            'HIT_INV[draglen ${cfg.name} dy=$dy] '
            'dragScrolls=${h.dragScrolls.value} '
            'browseArmed=${h.browseArmed.value.toStringAsFixed(1)} '
            'relocated=${controller.selection.baseOffset != before}',
          );
        }
      }
      expect(true, isTrue);
    });

    testWidgets('ballistic fling at 1× vs zoomed panEnabled', (tester) async {
      for (final cfg in [
        (scale: 1.0, panEnabled: false, name: '1x'),
        (scale: 2.4, panEnabled: true, name: 'z2.4_panOn'),
      ]) {
        final controller = longNote();
        final h = await pumpInteractiveViewerStack(
          tester,
          controller: controller,
          panEnabled: cfg.panEnabled,
        );
        applyZoomPan(h.transform, scale: cfg.scale);
        await tester.pumpAndSettle();
        final before = controller.selection.baseOffset;
        final box = tester.renderObject(find.byType(InteractiveViewer).first)
            as RenderBox;
        await tester.flingFrom(
          box.localToGlobal(const Offset(180, 200)),
          const Offset(0, 400),
          2500,
        );
        await tester.pumpAndSettle();
        debugPrint(
          'HIT_INV[fling ${cfg.name}] dragScrolls=${h.dragScrolls.value} '
          'anyScrolls=${h.anyScrolls.value} '
          'relocated=${controller.selection.baseOffset != before}',
        );
      }
      expect(true, isTrue);
    });
  });
}
