import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Modal sheet that records a short voice clip and returns the temp file path.
abstract final class NoteAudioRecorderSheet {
  static Future<({String path, int durationMs})?> show(BuildContext context) {
    return showModalBottomSheet<({String path, int durationMs})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _AudioRecorderSheet(),
    );
  }
}

class _AudioRecorderSheet extends StatefulWidget {
  const _AudioRecorderSheet();

  @override
  State<_AudioRecorderSheet> createState() => _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends State<_AudioRecorderSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _watch = Stopwatch();
  Timer? _tick;
  bool _recording = false;
  bool _busy = false;
  String? _path;
  String? _error;

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (_recording) {
      setState(() => _busy = true);
      try {
        final path = await _recorder.stop();
        _watch.stop();
        _tick?.cancel();
        setState(() {
          _recording = false;
          _path = path;
          _busy = false;
        });
      } catch (_) {
        setState(() {
          _busy = false;
          _error = l10n.audioRecordFailed;
        });
      }
      return;
    }

    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      setState(() => _error = l10n.audioPermissionDenied);
      return;
    }

    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'noteon_rec_${const Uuid().v4()}.m4a');
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      _watch
        ..reset()
        ..start();
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
      setState(() {
        _recording = true;
        _path = null;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = l10n.audioRecordFailed;
      });
    }
  }

  void _save() {
    final path = _path;
    if (path == null || !File(path).existsSync()) {
      return;
    }
    Navigator.of(context).pop((
      path: path,
      durationMs: _watch.elapsedMilliseconds,
    ));
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final elapsed = _watch.elapsed;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.recordAudioTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.recordAudioMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _format(elapsed),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: _recording ? AppColors.teal : null,
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _toggle,
                  icon: Icon(
                    _recording ? Icons.stop_rounded : Icons.mic_rounded,
                  ),
                  label: Text(
                    _recording ? l10n.audioStop : l10n.audioStartRecording,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: (!_recording && _path != null && !_busy)
                      ? _save
                      : null,
                  child: Text(l10n.insertAudio),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
