import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/note_block_model.dart';

/// Visual selection chrome around a note block (image/table).
///
/// Drag starts only from the handle — never from the child content itself.
class NoteBlockChrome extends StatelessWidget {
  const NoteBlockChrome({
    super.key,
    required this.selected,
    required this.blockIndex,
    required this.onAcceptDrop,
    required this.child,
  });

  final bool selected;
  final int blockIndex;
  final ValueChanged<int> onAcceptDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.tealLight : AppColors.teal;
    final borderColor = selected ? accent : Colors.transparent;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != blockIndex,
      onAcceptWithDetails: (details) => onAcceptDrop(details.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hovering)
              Container(
                height: 3,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadii.card,
                border: Border.all(
                  color: hovering ? accent : borderColor,
                  width: selected || hovering ? 2 : 1,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  child,
                  if (selected)
                    PositionedDirectional(
                      top: 4,
                      start: 4,
                      child: LongPressDraggable<int>(
                        data: blockIndex,
                        feedback: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: theme.colorScheme.surface,
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              color: accent,
                            ),
                          ),
                        ),
                        childWhenDragging: const Opacity(
                          opacity: 0.35,
                          child: _DragHandle(),
                        ),
                        child: const _DragHandle(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(8),
      elevation: 1,
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.drag_indicator_rounded, size: 22),
      ),
    );
  }
}

/// Compact action bar for the currently selected [NoteBlock].
class NoteBlockToolbar extends StatelessWidget {
  const NoteBlockToolbar({
    super.key,
    required this.selection,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onClear,
    required this.labels,
    this.onResize,
    this.onReplace,
    this.onEdit,
    this.onOcr,
  });

  final NoteBlockSelection selection;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final NoteBlockToolbarLabels labels;
  final VoidCallback? onResize;
  final VoidCallback? onReplace;
  final VoidCallback? onEdit;
  final VoidCallback? onOcr;

  @override
  Widget build(BuildContext context) {
    final kind = selection.block.kind;

    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              tooltip: labels.moveUp,
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
            IconButton(
              tooltip: labels.moveDown,
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.arrow_downward_rounded),
            ),
            if (kind == NoteBlockKind.image && onResize != null)
              IconButton(
                tooltip: labels.resizeImage,
                onPressed: onResize,
                icon: const Icon(Icons.photo_size_select_large_outlined),
              ),
            if (kind == NoteBlockKind.ink && onResize != null)
              IconButton(
                tooltip: labels.resizeImage,
                onPressed: onResize,
                icon: const Icon(Icons.photo_size_select_large_outlined),
              ),
            if (kind == NoteBlockKind.image && onReplace != null)
              IconButton(
                tooltip: labels.replaceImage,
                onPressed: onReplace,
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
            if (onOcr != null &&
                (kind == NoteBlockKind.image || kind == NoteBlockKind.ink))
              IconButton(
                tooltip: labels.ocrImage,
                onPressed: onOcr,
                icon: const Icon(Icons.document_scanner_outlined),
              ),
            if (onEdit != null &&
                (kind == NoteBlockKind.table ||
                    kind == NoteBlockKind.ink ||
                    kind == NoteBlockKind.pdf))
              IconButton(
                tooltip: labels.editBlock,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            IconButton(
              tooltip: labels.delete,
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            IconButton(
              tooltip: labels.cancel,
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class NoteBlockToolbarLabels {
  const NoteBlockToolbarLabels({
    required this.moveUp,
    required this.moveDown,
    required this.resizeImage,
    required this.replaceImage,
    required this.editBlock,
    required this.delete,
    required this.cancel,
    required this.ocrImage,
  });

  final String moveUp;
  final String moveDown;
  final String resizeImage;
  final String replaceImage;
  final String editBlock;
  final String delete;
  final String cancel;
  final String ocrImage;
}
