import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_lock_providers.dart';
import 'pin_pad.dart';

/// Opaque screen that covers all app content while the app is locked.
///
/// It sits above the navigator, so it uses no overlay-based widgets
/// (tooltips, text fields); dialogs open on the app navigator instead.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen>
    with WidgetsBindingObserver {
  bool _wasPaused = false;
  bool _showNoScreenLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptDevice());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    } else if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      _promptDevice();
    }
  }

  Future<void> _promptDevice() async {
    if (!mounted ||
        ref.read(appLockControllerProvider).method != AppLockMethod.biometric) {
      return;
    }
    await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithDevice(AppLocalizations.of(context).appLockReasonUnlock);
  }

  Future<void> _forgotPin() async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(appLockControllerProvider.notifier);
    if (!await controller.deviceHasScreenLock()) {
      if (mounted) {
        setState(() => _showNoScreenLock = true);
      }
      return;
    }
    await controller.resetPinWithDevice(l10n.appLockReasonReset);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lock = ref.watch(appLockControllerProvider);
    final controller = ref.read(appLockControllerProvider.notifier);
    final isPin = lock.method == AppLockMethod.pin;

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.appLockLockedTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 28),
                if (_showNoScreenLock) ...[
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.appLockNoScreenLockTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.appLockNoScreenLockBody),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _showNoScreenLock = false),
                    child: Text(l10n.appLockOk),
                  ),
                ] else if (isPin) ...[
                  PinPad(
                    title: l10n.appLockEnterPin,
                    length: controller.pinLength,
                    lockoutRemaining: controller.lockoutRemaining,
                    onComplete: (pin) async {
                      final result = await controller.unlockWithPin(pin);
                      return result == PinCheck.ok
                          ? null
                          : result == PinCheck.wrong
                              ? l10n.appLockWrongPin
                              : '';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _forgotPin,
                    child: Text(l10n.appLockForgotPin),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _promptDevice,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(l10n.appLockUseBiometrics),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
