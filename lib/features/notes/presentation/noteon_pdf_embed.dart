import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../data/note_block_model.dart';
import '../data/noteon_pdf_payload.dart';
import 'note_block_chrome.dart';
import 'noteon_image_embed.dart';

/// Renders a PDF attachment card inside the Quill note body.
class NoteonPdfEmbedBuilder extends EmbedBuilder {
  const NoteonPdfEmbedBuilder({
    this.noteId,
    this.interaction,
    this.onOpen,
  });

  final int? noteId;
  final NoteBlockInteraction? interaction;
  final void Function(NoteonPdfData data)? onOpen;

  @override
  String get key => NoteonPdfBlockEmbed.embedType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = NoteonPdfBlockEmbed.tryParseEmbeddable(embedContext.node.value) ??
        NoteonPdfPayload.decode(embedContext.node.value.data);
    return _NoteonEmbeddedPdf(
      data: data,
      documentOffset: embedContext.node.documentOffset,
      readOnly: embedContext.readOnly,
      interaction: interaction,
      onOpen: onOpen,
    );
  }
}

class _NoteonEmbeddedPdf extends StatelessWidget {
  const _NoteonEmbeddedPdf({
    required this.data,
    required this.documentOffset,
    required this.readOnly,
    this.interaction,
    this.onOpen,
  });

  final NoteonPdfData data;
  final int documentOffset;
  final bool readOnly;
  final NoteBlockInteraction? interaction;
  final void Function(NoteonPdfData data)? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = data.title?.trim().isNotEmpty == true
        ? data.title!
        : l10n.pdfDocumentLabel;

    final card = Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: AppRadii.card,
      child: InkWell(
        borderRadius: AppRadii.card,
        onTap: readOnly
            ? null
            : () {
                if (interaction != null) {
                  final blocks =
                      NoteBlockModel.listBlocks(interaction!.controller.document);
                  final index = interaction!.indexForOffset(
                    documentOffset,
                    NoteBlockKind.pdf,
                  );
                  if (index != null && index < blocks.length) {
                    interaction!.onSelect(blocks[index]);
                  }
                }
              },
        onDoubleTap: readOnly || onOpen == null || data.isEmpty
            ? null
            : () => onOpen!(data),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.15),
                  borderRadius: AppRadii.control,
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.pdfTapToAnnotate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.editBlock,
                onPressed: readOnly || onOpen == null || data.isEmpty
                    ? null
                    : () => onOpen!(data),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );

    if (readOnly || interaction == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ValueListenableBuilder<NoteBlockSelection?>(
        valueListenable: interaction!.selection,
        builder: (context, selection, _) {
          final selected = selection != null &&
              selection.block.kind == NoteBlockKind.pdf &&
              selection.block.start == documentOffset;
          final blockIndex = interaction!.indexForOffset(
                documentOffset,
                NoteBlockKind.pdf,
              ) ??
              0;
          return NoteBlockChrome(
            selected: selected,
            blockIndex: blockIndex,
            onAcceptDrop: (from) {
              interaction!.onAcceptDrop(fromIndex: from, toIndex: blockIndex);
            },
            child: card,
          );
        },
      ),
    );
  }
}
