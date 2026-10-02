import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_lock_providers.dart';
import 'pin_pad.dart';

/// Dialogs for app-lock setup and re-authentication (used from settings).
class AppLockDialogs {
  const AppLockDialogs._();

  /// Asks for a new PIN twice. Returns the PIN, or null if cancelled.
  static Future<String?> createPin(
    BuildContext context,
    WidgetRef ref, {
    String? title,
  }) {
    final length = ref.read(appLockControllerProvider.notifier).pinLength;
    return showDialog<String>(
      context: context,
      builder: (context) => _CreatePinDialog(length: length, title: title),
    );
  }

  /// Requires the current unlock: system prompt in biometric mode, the
  /// current PIN in PIN mode. Returns true when confirmed.
  static Future<bool> confirmCurrent(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(appLockControllerProvider.notifier);
    if (ref.read(appLockControllerProvider).method == AppLockMethod.biometric) {
      return ref
          .read(deviceAuthProvider)
          .authenticate(reason: l10n.appLockReasonConfirm);
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          content: PinPad(
            title: l10n.appLockEnterPin,
            length: controller.pinLength,
            lockoutRemaining: controller.lockoutRemaining,
            onComplete: (pin) async {
              final result = await controller.verifyPin(pin);
              if (result == PinCheck.ok && context.mounted) {
                Navigator.of(context).pop(true);
              }
              return result == PinCheck.ok
                  ? null
                  : result == PinCheck.wrong
                      ? l10n.appLockWrongPin
                      : '';
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }

  /// After a Forgot PIN reset: offer to set a new PIN right away.
  static Future<void> offerNewPin(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(appLockControllerProvider.notifier);
    controller.dismissNewPinPrompt();
    final pin = await createPin(
      context,
      ref,
      title: AppLocalizations.of(context).appLockSetNewPinTitle,
    );
    if (pin != null) {
      await controller.setPin(pin);
    }
  }
}

class _CreatePinDialog extends StatefulWidget {
  const _CreatePinDialog({required this.length, this.title});

  final int length;
  final String? title;

  @override
  State<_CreatePinDialog> createState() => _CreatePinDialogState();
}

class _CreatePinDialogState extends State<_CreatePinDialog> {
  String? _first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: widget.title == null ? null : Text(widget.title!),
      content: PinPad(
        title: _first == null ? l10n.appLockCreatePin : l10n.appLockConfirmPin,
        length: widget.length,
        onComplete: (pin) async {
          if (_first == null) {
            setState(() => _first = pin);
            return null;
          }
          if (pin == _first) {
            Navigator.of(context).pop(pin);
            return null;
          }
          setState(() => _first = null);
          return l10n.appLockPinMismatch;
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
