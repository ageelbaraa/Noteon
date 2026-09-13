import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../shared/navigation/noteon_page_route.dart';
import '../../notes/presentation/notes_providers.dart';
import '../domain/backup_models.dart';
import 'backup_import_mode_dialog.dart';
import 'backup_passphrase_dialogs.dart';
import 'nearby_receive_screen.dart';
import 'nearby_send_screen.dart';
import 'transfer_providers.dart';

/// Settings-driven export / import / nearby transfer flows.
abstract final class BackupTransferActions {
  static Future<void> exportBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final passphraseResult = await showExportBackupPassphraseDialog(context);
    if (passphraseResult == null || !context.mounted) return;

    final passphrase = passphraseResult.passphrase;
    _showProgressDialog(context, l10n.backupExportProgress);

    File? tempFile;
    try {
      final bytes = await ref
          .read(backupServiceProvider)
          .exportEncryptedBackup(passphrase: passphrase);

      final tempDir = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('.', '');
      tempFile = File(p.join(tempDir.path, 'noteon_backup_$stamp.noteonbak'));
      await tempFile.writeAsBytes(bytes, flush: true);

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: 'application/octet-stream')],
          subject: l10n.backupShareSubject,
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupExportReady)),
        );
      }
    } on BackupException catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(context, _mapError(l10n, e));
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(context, l10n.backupExportFailed);
      }
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  static Future<void> importBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['noteonbak'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return;

    final path = picked.files.single.path;
    if (path == null) {
      _showError(context, l10n.backupImportFailed);
      return;
    }

    final bytes = Uint8List.fromList(await File(path).readAsBytes());
    if (!context.mounted) return;
    await importBackupBytes(context, ref, bytes);
  }

  /// Imports an already-loaded `.noteonbak` (file pick or nearby download).
  static Future<void> importBackupBytes(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes,
  ) async {
    final l10n = AppLocalizations.of(context);

    final passphraseResult = await showImportBackupPassphraseDialog(context);
    if (passphraseResult == null || !context.mounted) return;

    final mode = await showBackupImportModeDialog(context);
    if (mode == null || !context.mounted) return;

    final passphrase = passphraseResult.passphrase;
    _showProgressDialog(context, l10n.backupImportProgress);

    try {
      final result = await ref.read(backupServiceProvider).importEncryptedBackup(
            fileBytes: bytes,
            passphrase: passphrase,
            mode: mode,
          );

      final session = ref.read(unlockedNoteSessionProvider);
      session?.clearSensitive();
      ref.read(unlockedNoteSessionProvider.notifier).state = null;

      await ref.read(notesListProvider.notifier).refresh();
      await ref.read(foldersListProvider.notifier).refresh();
      await ref.read(tagsListProvider.notifier).refresh();

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.backupImportSuccess(result.notesImported),
            ),
          ),
        );
      }
    } on BackupException catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(context, _mapError(l10n, e));
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(context, l10n.backupImportFailed);
      }
    }
  }

  static Future<void> sendNearby(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final passphraseResult = await showExportBackupPassphraseDialog(context);
    if (passphraseResult == null || !context.mounted) return;

    await Navigator.of(context).push<void>(
      NoteonPageRoute(
        builder: (_) => NearbySendScreen(
          passphrase: passphraseResult.passphrase,
        ),
      ),
    );
  }

  static Future<void> receiveNearby(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      NoteonPageRoute(builder: (_) => const NearbyReceiveScreen()),
    );
    if (bytes == null || !context.mounted) return;
    await importBackupBytes(context, ref, bytes);
  }

  static void _showProgressDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static String _mapError(AppLocalizations l10n, BackupException error) {
    switch (error.code) {
      case BackupErrorCode.passphraseTooShort:
        return l10n.passwordTooShort;
      case BackupErrorCode.incorrectPassphrase:
        return l10n.backupIncorrectPassphrase;
      case BackupErrorCode.invalidFormat:
      case BackupErrorCode.unsupportedVersion:
      case BackupErrorCode.corruptPayload:
        return l10n.backupCorruptFile;
      case BackupErrorCode.missingMedia:
        return l10n.backupExportFailed;
      case BackupErrorCode.cancelled:
        return l10n.cancel;
      case BackupErrorCode.ioFailure:
        return l10n.backupImportFailed;
    }
  }
}
