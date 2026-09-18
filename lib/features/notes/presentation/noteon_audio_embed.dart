import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/note_block_model.dart';
import '../data/noteon_audio_payload.dart';
import 'note_block_chrome.dart';
import 'noteon_image_embed.dart';

/// Quill custom embed type for Noteon audio attachments.
class NoteonAudioBlockEmbed extends CustomBlockEmbed {
  const NoteonAudioBlockEmbed(String data) : super(embedType, data);

  static const String embedType = 'noteonAudio';

  factory NoteonAudioBlockEmbed.fromPayload({
    required String path,
    int? durationMs,
  }) {
    return NoteonAudioBlockEmbed(
      NoteonAudioPayload.encode(path: path, durationMs: durationMs),
    );
  }

  static ({String path, int? durationMs})? tryParseEmbeddable(
    Embeddable embeddable,
  ) {
    try {
      if (embeddable.type == embedType) {
        return NoteonAudioPayload.decode('${embeddable.data}');
      }
      if (embeddable.type == BlockEmbed.customType) {
        final custom = CustomBlockEmbed.fromJsonString('${embeddable.data}');
        if (custom.type == embedType) {
          return NoteonAudioPayload.decode(custom.data);
        }
      }
    } catch (_) {
      // Ignore malformed embeds.
    }
    return null;
  }
}

/// Renders an audio embed with play/pause and block selection chrome.
class NoteonAudioEmbedBuilder extends EmbedBuilder {
  const NoteonAudioEmbedBuilder({
    this.noteId,
    this.interaction,
  });

  final int? noteId;
  final NoteBlockInteraction? interaction;

  @override
  String get key => NoteonAudioBlockEmbed.embedType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final parsed =
        NoteonAudioBlockEmbed.tryParseEmbeddable(embedContext.node.value);
    final payload = parsed ??
        NoteonAudioPayload.decode(embedContext.node.value.data);
    final offset = embedContext.node.documentOffset;
    return _NoteonEmbeddedAudio(
      relativePath: payload.path,
      durationMs: payload.durationMs,
      noteId: noteId,
      documentOffset: offset,
      readOnly: embedContext.readOnly,
      interaction: interaction,
    );
  }
}

class _NoteonEmbeddedAudio extends ConsumerStatefulWidget {
  const _NoteonEmbeddedAudio({
    required this.relativePath,
    required this.durationMs,
    required this.noteId,
    required this.documentOffset,
    required this.readOnly,
    required this.interaction,
  });

  final String relativePath;
  final int? durationMs;
  final int? noteId;
  final int documentOffset;
  final bool readOnly;
  final NoteBlockInteraction? interaction;

  @override
  ConsumerState<_NoteonEmbeddedAudio> createState() =>
      _NoteonEmbeddedAudioState();
}

class _NoteonEmbeddedAudioState extends ConsumerState<_NoteonEmbeddedAudio> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  bool _loading = false;
  bool _playing = false;
  String? _tempPath;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playing = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _playing = false;
          unawaited(_player.seek(Duration.zero));
          unawaited(_player.pause());
        }
      });
    });
  }

  @override
  void dispose() {
    unawaited(_playerSub?.cancel());
    unawaited(_player.dispose());
    final temp = _tempPath;
    if (temp != null) {
      unawaited(
        File(temp).delete().then((_) {}, onError: (_) {}),
      );
    }
    super.dispose();
  }

  Future<String?> _resolvePlayablePath() async {
    final session = ref.read(unlockedNoteSessionProvider);
    if (session != null &&
        widget.noteId != null &&
        session.noteId == widget.noteId &&
        session.mediaBytes.containsKey(widget.relativePath)) {
      final bytes = session.mediaBytes[widget.relativePath]!;
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(dir.path, 'noteon_audio_${widget.relativePath.hashCode}.m4a'),
      );
      await file.writeAsBytes(bytes, flush: true);
      _tempPath = file.path;
      return file.path;
    }

    final media = ref.read(mediaStorageProvider);
    final file = await media.fileFor(widget.relativePath);
    return file?.path;
  }

  Future<void> _togglePlay() async {
    if (_loading) {
      return;
    }
    if (_playing) {
      await _player.pause();
      return;
    }

    setState(() => _loading = true);
    try {
      final path = await _resolvePlayablePath();
      if (path == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.audioMissing)),
          );
        }
        return;
      }
      if (_player.audioSource == null) {
        await _player.setAudioSource(AudioSource.file(path));
      }
      await _player.play();
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.audioPlayFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final interaction = widget.interaction;

    final knownDuration = widget.durationMs != null
        ? Duration(milliseconds: widget.durationMs!)
        : null;

    final card = Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: AppRadii.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: _togglePlay,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
              tooltip: _playing ? l10n.audioPause : l10n.audioPlay,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.audioLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, snapshot) {
                      final pos = snapshot.data ?? Duration.zero;
                      final total = _player.duration ?? knownDuration;
                      final label = total == null
                          ? _formatDuration(pos)
                          : '${_formatDuration(pos)} / ${_formatDuration(total)}';
                      return Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Icon(
              Icons.graphic_eq_rounded,
              color: AppColors.teal.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );

    if (widget.readOnly || interaction == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ValueListenableBuilder<NoteBlockSelection?>(
        valueListenable: interaction.selection,
        builder: (context, selection, _) {
          final selected = selection != null &&
              selection.block.kind == NoteBlockKind.audio &&
              selection.block.start == widget.documentOffset;
          final blockIndex = interaction.indexForOffset(
                widget.documentOffset,
                NoteBlockKind.audio,
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
                  final blocks =
                      NoteBlockModel.listBlocks(interaction.controller.document);
                  if (blockIndex >= 0 && blockIndex < blocks.length) {
                    interaction.onSelect(blocks[blockIndex]);
                  }
                },
                child: card,
              ),
            ),
          );
        },
      ),
    );
  }
}
