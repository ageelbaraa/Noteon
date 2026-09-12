import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/media_providers.dart';
import '../../../core/theme/app_colors.dart';

/// Renders Noteon-local image embeds (relative paths under noteon_media).
///
/// When a note is unlocked in-memory, prefers decrypted bytes over disk files
/// so plaintext media is not required on disk for locked notes.
class NoteonImageEmbedBuilder extends EmbedBuilder {
  const NoteonImageEmbedBuilder({this.noteId});

  final int? noteId;

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final relativePath = embedContext.node.value.data.trim();
    return _NoteonEmbeddedImage(
      relativePath: relativePath,
      noteId: noteId,
    );
  }
}

class _NoteonEmbeddedImage extends ConsumerWidget {
  const _NoteonEmbeddedImage({
    required this.relativePath,
    this.noteId,
  });

  final String relativePath;
  final int? noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(unlockedNoteSessionProvider);
    Uint8List? sessionBytes;
    if (session != null &&
        noteId != null &&
        session.noteId == noteId &&
        session.mediaBytes.containsKey(relativePath)) {
      sessionBytes = session.mediaBytes[relativePath];
    }

    if (sessionBytes != null) {
      return _buildImage(context, l10n, MemoryImage(sessionBytes));
    }

    final media = ref.watch(mediaStorageProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FutureBuilder(
        future: media.fileFor(relativePath),
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

  Widget _buildImage(
    BuildContext context,
    AppLocalizations l10n,
    ImageProvider provider,
  ) {
    final cacheWidth =
        (MediaQuery.sizeOf(context).width * 2).round().clamp(640, 2048);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: AppRadii.card,
        child: Image(
          image: ResizeImage(provider, width: cacheWidth),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              _MissingImagePlaceholder(message: l10n.imageMissing),
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
