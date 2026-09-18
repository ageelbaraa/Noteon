import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/features/notes/presentation/note_editor_zoom_viewport.dart';

void main() {
  test('pinch out then in from 1× returns to the original scale', () {
    const startScale = 1.0;
    const startSpan = 120.0;
    const minScale = 0.25;
    const maxScale = 8.0;

    final zoomed = noteEditorZoomScale(
      startScale: startScale,
      startSpan: startSpan,
      span: 240,
      minScale: minScale,
      maxScale: maxScale,
    );
    expect(zoomed, 2.0);

    final back = noteEditorZoomScale(
      startScale: startScale,
      startSpan: startSpan,
      span: startSpan,
      minScale: minScale,
      maxScale: maxScale,
    );
    expect(back, 1.0);
  });

  test('a new pinch-in gesture from 2× can return to 1×', () {
    final zoomedOut = noteEditorZoomScale(
      startScale: 2,
      startSpan: 200,
      span: 100,
      minScale: 0.25,
      maxScale: 8,
    );
    expect(zoomedOut, 1.0);
  });

  test('pinch-in from 1× can shrink below default', () {
    expect(
      noteEditorZoomScale(
        startScale: 1,
        startSpan: 100,
        span: 50,
        minScale: 0.25,
        maxScale: 8,
      ),
      0.5,
    );
  });

  test('scale is clamped only at the wide range ends', () {
    expect(
      noteEditorZoomScale(
        startScale: 1,
        startSpan: 100,
        span: 10,
        minScale: 0.25,
        maxScale: 8,
      ),
      0.25,
    );
    expect(
      noteEditorZoomScale(
        startScale: 2,
        startSpan: 100,
        span: 800,
        minScale: 0.25,
        maxScale: 8,
      ),
      8.0,
    );
  });

  test('zoom matrix keeps the scene point under the fingers', () {
    const focal = Offset(150, 100);
    const scene = Offset(80, 40);
    const scale = 2.0;
    final matrix = noteEditorZoomMatrix(
      scale: scale,
      focalViewport: focal,
      focalScene: scene,
    );

    final projected = MatrixUtils.transformPoint(matrix, scene);
    expect(projected.dx, closeTo(focal.dx, 0.001));
    expect(projected.dy, closeTo(focal.dy, 0.001));
    expect(matrix.getMaxScaleOnAxis(), closeTo(scale, 0.001));
  });

  test('1× matrix around a focal point is identity in effect', () {
    const focal = Offset(150, 100);
    final matrix = noteEditorZoomMatrix(
      scale: 1,
      focalViewport: focal,
      focalScene: focal,
    );
    expect(matrix.getMaxScaleOnAxis(), closeTo(1, 0.001));
    expect(MatrixUtils.transformPoint(matrix, focal), focal);
  });
}
