import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../data/backup_service.dart';

/// Result of a backup passphrase dialog. Null means cancelled.
class BackupPassphraseResult {
  const BackupPassphraseResult({required this.passphrase});

  final String passphrase;
}

Future<BackupPassphraseResult?> showExportBackupPassphraseDialog(
  BuildContext context,
) {
  return showDialog<BackupPassphraseResult>(
    context: context,
    builder: (context) => const _SetBackupPassphraseDialog(),
  );
}

Future<BackupPassphraseResult?> showImportBackupPassphraseDialog(
  BuildContext context,
) {
  return showDialog<BackupPassphraseResult>(
    context: context,
    builder: (context) => const _UnlockBackupPassphraseDialog(),
  );
}

class _SetBackupPassphraseDialog extends StatefulWidget {
  const _SetBackupPassphraseDialog();

  @override
  State<_SetBackupPassphraseDialog> createState() =>
      _SetBackupPassphraseDialogState();
}

class _SetBackupPassphraseDialogState
    extends State<_SetBackupPassphraseDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.clear();
    _confirmController.clear();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < BackupService.minPassphraseLength) {
      setState(() => _error = l10n.passwordTooShort);
      return;
    }
    if (password != confirm) {
      setState(() => _error = l10n.passwordMismatch);
      return;
    }

    Navigator.of(context).pop(BackupPassphraseResult(passphrase: password));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.backupExportTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.backupExportMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.backupPassphraseNoRecoveryWarning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.backupPassphraseLabel,
                suffixIcon: IconButton(
                  tooltip: l10n.togglePasswordVisibility,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              textInputAction: TextInputAction.next,
              enableSuggestions: false,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\n')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.confirmPasswordLabel,
              ),
              textInputAction: TextInputAction.done,
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          child: Text(l10n.backupExportAction),
        ),
      ],
    );
  }
}

class _UnlockBackupPassphraseDialog extends StatefulWidget {
  const _UnlockBackupPassphraseDialog();

  @override
  State<_UnlockBackupPassphraseDialog> createState() =>
      _UnlockBackupPassphraseDialogState();
}

class _UnlockBackupPassphraseDialogState
    extends State<_UnlockBackupPassphraseDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.clear();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      BackupPassphraseResult(passphrase: _passwordController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.backupImportTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.backupImportPassphraseMessage),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.backupPassphraseLabel,
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.teal),
              suffixIcon: IconButton(
                tooltip: l10n.togglePasswordVisibility,
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            textInputAction: TextInputAction.done,
            enableSuggestions: false,
            autocorrect: false,
            onSubmitted: (_) => _submit(),
          ),
        ],
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
