import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/backup_models.dart';

/// Asks the user to choose merge vs replace, with typed confirm for replace.
Future<BackupImportMode?> showBackupImportModeDialog(BuildContext context) {
  return showDialog<BackupImportMode>(
    context: context,
    builder: (context) => const _BackupImportModeDialog(),
  );
}

class _BackupImportModeDialog extends StatefulWidget {
  const _BackupImportModeDialog();

  @override
  State<_BackupImportModeDialog> createState() =>
      _BackupImportModeDialogState();
}

class _BackupImportModeDialogState extends State<_BackupImportModeDialog> {
  BackupImportMode _mode = BackupImportMode.merge;
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_mode == BackupImportMode.replace) {
      final expected = l10n.backupReplaceConfirmWord;
      if (_confirmController.text.trim() != expected) {
        setState(() => _error = l10n.backupReplaceConfirmMismatch);
        return;
      }
    }
    Navigator.of(context).pop(_mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.backupImportModeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.backupImportModeMessage,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<BackupImportMode>(
              segments: [
                ButtonSegment(
                  value: BackupImportMode.merge,
                  label: Text(l10n.backupImportModeMerge),
                  tooltip: l10n.backupImportModeMergeSubtitle,
                ),
                ButtonSegment(
                  value: BackupImportMode.replace,
                  label: Text(l10n.backupImportModeReplace),
                  tooltip: l10n.backupImportModeReplaceSubtitle,
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) {
                setState(() {
                  _mode = value.first;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              _mode == BackupImportMode.replace
                  ? l10n.backupImportModeReplaceSubtitle
                  : l10n.backupImportModeMergeSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_mode == BackupImportMode.replace) ...[
              const SizedBox(height: 12),
              Text(
                l10n.backupReplaceConfirmPrompt(l10n.backupReplaceConfirmWord),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.backupReplaceConfirmLabel,
                ),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.backupImportAction),
        ),
      ],
    );
  }
}
