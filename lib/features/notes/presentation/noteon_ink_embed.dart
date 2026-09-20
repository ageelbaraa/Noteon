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
import '../data/noteon_ink_payload.dart';
import 'note_block_chrome.dart';
import 'noteon_image_embed.dart';

/// Renders a vector-ink embed preview (PNG) with block selection chrome.
class NoteonInkEmbedBuilder extends EmbedBuilder {
  const NoteonInkEmbedBuilder({
    this.noteId,
    this.interaction,
  });

  final int? noteId;
  final NoteBlockInteraction? interaction;

  @override
  String get key => NoteonInkBlockEmbed.embedType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = NoteonInkBlockEmbed.tryParseEmbeddable(embedContext.node.value) ??
        NoteonInkPayload.decode(embedContext.node.value.data);
    // Key by preview path only — documentOffset shifts while typing above the
    // embed and would remount State / re-trigger the file Future.
    return _NoteonEmbeddedInk(
      key: ValueKey('ink:${data.previewPath}'),
      data: data,
      noteId: noteId,
      documentOffset: embedContext.node.documentOffset,
      readOnly: embedContext.readOnly,
      interaction: interaction,
    );
  }
}

class _NoteonEmbeddedInk extends ConsumerStatefulWidget {
  const _NoteonEmbeddedInk({
    super.key,
    required this.data,
    required this.documentOffset,
    required this.readOnly,
    this.noteId,
    this.interaction,
  });

  final NoteonInkData data;
  final int? noteId;
  final int documentOffset;
  final bool readOnly;
  final NoteBlockInteraction? interaction;

  @override
  ConsumerState<_NoteonEmbeddedInk> createState() => _NoteonEmbeddedInkState();
}

class _NoteonEmbeddedInkState extends ConsumerState<_NoteonEmbeddedInk> {
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
  void didUpdateWidget(covariant _NoteonEmbeddedInk oldWidget) {
    super.didUpdateWidget(oldWidget);
    _documentOffset = widget.documentOffset;
    if (oldWidget.data.previewPath != widget.data.previewPath ||
        oldWidget.noteId != widget.noteId) {
      _fileFuture = null;
      _futurePath = null;
      _ensureFileFuture();
    }
  }

  void _ensureFileFuture() {
    final path = widget.data.previewPath;
    if (path.isEmpty) {
      return;
    }
    if (_futurePath == path && _fileFuture != null) {
      return;
    }
    _futurePath = path;
    _fileFuture = ref.read(mediaStorageProvider).fileFor(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (widget.data.isEmpty) {
      return _missing(l10n.sketchSaveFailed);
    }

    final session = ref.watch(unlockedNoteSessionProvider);
    Uint8List? sessionBytes;
    if (session != null &&
        widget.noteId != null &&
        session.noteId == widget.noteId &&
        session.mediaBytes.containsKey(widget.data.previewPath)) {
      sessionBytes = session.mediaBytes[widget.data.previewPath];
    }

    final Widget preview;
    if (sessionBytes != null) {
      preview = _previewImage(MemoryImage(sessionBytes), theme, l10n);
    } else {
      preview = FutureBuilder<File?>(
        // Stable future — recreating it on every Quill rebuild caused a
        // loading-spinner flash while typing near ink embeds.
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
            return _missing(l10n.imageMissing);
          }
          return _previewImage(FileImage(file), theme, l10n);
        },
      );
    }

    if (widget.readOnly || widget.interaction == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: preview,
      );
    }

    final interaction = widget.interaction!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ValueListenableBuilder<NoteBlockSelection?>(
        valueListenable: interaction.selection,
        builder: (context, selection, _) {
          final selected = selection != null &&
              selection.block.kind == NoteBlockKind.ink &&
              selection.block.start == _documentOffset;
          final blockIndex = interaction.indexForOffset(
                _documentOffset,
                NoteBlockKind.ink,
              ) ??
              0;
          return NoteBlockChrome(
            selected: selected,
            blockIndex: blockIndex,
            onAcceptDrop: (from) {
              interaction.onAcceptDrop(fromIndex: from, toIndex: blockIndex);
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadii.card,
                onTap: () {
                  final blocks = NoteBlockModel.listBlocks(
                    interaction.controller.document,
                  );
                  if (blockIndex >= 0 && blockIndex < blocks.length) {
                    interaction.onSelect(blocks[blockIndex]);
                  }
                },
                child: preview,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _previewImage(
    ImageProvider provider,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final width = widget.data.displayWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width ?? double.infinity,
              maxHeight: 280,
            ),
            child: ClipRRect(
              borderRadius: AppRadii.card,
              child: Image(
                image: provider,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _missing(l10n.imageMissing),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.inkDrawingLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _missing(String message) {
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: AppRadii.card,
      ),
      child: Text(message),
    );
  }
}
