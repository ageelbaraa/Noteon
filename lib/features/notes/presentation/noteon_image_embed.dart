import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/note_block_model.dart';
import '../data/noteon_image_payload.dart';
import 'note_block_chrome.dart';

/// Callbacks for block selection / reordering (owned by the note editor).
class NoteBlockInteraction {
  const NoteBlockInteraction({
    required this.selection,
    required this.controller,
    required this.onSelect,
    required this.onAcceptDrop,
  });

  final ValueNotifier<NoteBlockSelection?> selection;
  final QuillController controller;
  final void Function(NoteBlock block) onSelect;
  final void Function({required int fromIndex, required int toIndex})
      onAcceptDrop;

  int? indexForOffset(int offset, NoteBlockKind kind) {
    final blocks = NoteBlockModel.listBlocks(controller.document);
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].kind == kind && blocks[i].start == offset) {
        return i;
      }
    }
    return null;
  }
}

/// Renders Noteon-local image embeds (relative paths under noteon_media).
class NoteonImageEmbedBuilder extends EmbedBuilder {
  const NoteonImageEmbedBuilder({
    this.noteId,
    this.interaction,
  });

  final int? noteId;
  final NoteBlockInteraction? interaction;

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final payload = NoteonImagePayload.decode(embedContext.node.value.data);
    final relativePath = payload.path;
    // Key by path only — including documentOffset recreated the State on every
    // keystroke above the image (offsets shift), which re-triggered file load
    // and caused visible flicker while typing.
    return _NoteonEmbeddedImage(
      key: ValueKey('img:$relativePath'),
      relativePath: relativePath,
      displayWidth: payload.displayWidth,
      noteId: noteId,
      documentOffset: embedContext.node.documentOffset,
      readOnly: embedContext.readOnly,
      interaction: interaction,
    );
  }
}

class _NoteonEmbeddedImage extends ConsumerStatefulWidget {
  const _NoteonEmbeddedImage({
    super.key,
    required this.relativePath,
    required this.documentOffset,
    required this.readOnly,
    this.displayWidth,
    this.noteId,
    this.interaction,
  });

  final String relativePath;
  final double? displayWidth;
  final int? noteId;
  final int documentOffset;
  final bool readOnly;
  final NoteBlockInteraction? interaction;

  @override
  ConsumerState<_NoteonEmbeddedImage> createState() =>
      _NoteonEmbeddedImageState();
}

class _NoteonEmbeddedImageState extends ConsumerState<_NoteonEmbeddedImage> {
  Future<File?>? _fileFuture;
  String? _futurePath;
  late int _documentOffset;

  @override
  void initState() {
    super.initState();
    _documentOffset = widget.documentOffset;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureFileFuture();
  }

  @override
  void didUpdateWidget(covariant _NoteonEmbeddedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _documentOffset = widget.documentOffset;
    if (oldWidget.relativePath != widget.relativePath ||
        oldWidget.noteId != widget.noteId) {
      _fileFuture = null;
      _futurePath = null;
      _ensureFileFuture();
    }
  }

  void _ensureFileFuture() {
    if (_futurePath == widget.relativePath && _fileFuture != null) {
      return;
    }
    _futurePath = widget.relativePath;
    _fileFuture = ref.read(mediaStorageProvider).fileFor(widget.relativePath);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(unlockedNoteSessionProvider);
    Uint8List? sessionBytes;
    if (session != null &&
        widget.noteId != null &&
        session.noteId == widget.noteId &&
        session.mediaBytes.containsKey(widget.relativePath)) {
      sessionBytes = session.mediaBytes[widget.relativePath];
    }

    final Widget image;
    if (sessionBytes != null) {
      image = _buildImage(context, l10n, MemoryImage(sessionBytes));
    } else {
      image = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: FutureBuilder<File?>(
          // Stable future — recreating it on every Quill rebuild caused
          // loading-spinner flicker while typing near images.
          future: _fileFuture,
          builder: (context, snapshot) {
            final file = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (file == null) {
              return _MissingImagePlaceholder(message: l10n.imageMissing);
            }
            return _buildImage(context, l10n, FileImage(file));
          },
        ),
      );
    }

    final interaction = widget.interaction;
    if (widget.readOnly || interaction == null) {
      return image;
    }

    return ValueListenableBuilder<NoteBlockSelection?>(
      valueListenable: interaction.selection,
      builder: (context, selection, _) {
        final selected = selection != null &&
            selection.block.kind == NoteBlockKind.image &&
            selection.block.start == _documentOffset;
        final blockIndex = interaction.indexForOffset(
              _documentOffset,
              NoteBlockKind.image,
            ) ??
            0;

        return NoteBlockChrome(
          selected: selected,
          blockIndex: blockIndex,
          onAcceptDrop: (fromIndex) {
            interaction.onAcceptDrop(
              fromIndex: fromIndex,
              toIndex: blockIndex,
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              interaction.onSelect(
                NoteBlock(
                  kind: NoteBlockKind.image,
                  start: _documentOffset,
                  length: 1,
                  imagePath: widget.relativePath,
                  displayWidth: widget.displayWidth,
                ),
              );
            },
            child: image,
          ),
        );
      },
    );
  }

  Widget _buildImage(
    BuildContext context,
    AppLocalizations l10n,
    ImageProvider provider,
  ) {
    final cacheWidth =
        (MediaQuery.sizeOf(context).width * 2).round().clamp(640, 2048);
    final maxW = widget.displayWidth;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 240,
            maxWidth: maxW ?? double.infinity,
          ),
          child: ClipRRect(
            borderRadius: AppRadii.card,
            child: Image(
              image: ResizeImage(provider, width: cacheWidth),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              width: maxW,
              errorBuilder: (_, _, _) =>
                  _MissingImagePlaceholder(message: l10n.imageMissing),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingImagePlaceholder extends StatelessWidget {
  const _MissingImagePlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: AppRadii.card,
      ),
      child: Row(
        children: [
          const Icon(Icons.broken_image_outlined, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
