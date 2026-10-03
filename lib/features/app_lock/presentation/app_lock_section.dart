import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_lock_providers.dart';
import '../../../core/security/device_auth.dart';
import '../../../shared/widgets/noteon_group_surface.dart';
import 'app_lock_dialogs.dart';

/// Settings → Security: app lock toggle, unlock method and PIN change.
class AppLockSection extends ConsumerWidget {
  const AppLockSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lock = ref.watch(appLockControllerProvider);
    final isPin = lock.method == AppLockMethod.pin;

    return FutureBuilder<DeviceAuthCapabilities>(
      future: ref.read(deviceAuthProvider).capabilities(),
      builder: (context, snapshot) {
        final hasBiometrics = snapshot.data?.hasBiometrics == true;

        return NoteonGroupSurface(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline_rounded),
              title: Text(l10n.appLockTitle),
              subtitle: Text(l10n.appLockSubtitle),
              value: lock.enabled,
              onChanged: (value) =>
                  value ? _enable(context, ref) : _disable(context, ref),
            ),
            if (lock.enabled && hasBiometrics)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 4,
                        end: 4,
                        bottom: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fingerprint, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.appLockUnlockWith,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SegmentedButton<AppLockMethod>(
                      showSelectedIcon: true,
                      segments: [
                        ButtonSegment(
                          value: AppLockMethod.biometric,
                          label: Text(l10n.appLockMethodBiometrics),
                        ),
                        ButtonSegment(
                          value: AppLockMethod.pin,
                          label: Text(l10n.appLockMethodPin),
                        ),
                      ],
                      selected: {lock.method},
                      onSelectionChanged: (value) =>
                          _switchMethod(context, ref, value.first),
                    ),
                  ],
                ),
              ),
            if (lock.enabled && isPin)
              NoteonGroupTile(
                leading: const Icon(Icons.pin_outlined),
                title: l10n.appLockChangePin,
                onTap: () => _changePin(context, ref),
              ),
          ],
        );
      },
    );
  }

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(appLockControllerProvider.notifier);
    final auth = ref.read(deviceAuthProvider);
    if ((await auth.capabilities()).hasBiometrics) {
      // One biometric confirmation, then the lock uses biometrics.
      if (await auth.authenticate(
        reason: l10n.appLockReasonEnable,
        biometricOnly: true,
      )) {
        await controller.enableBiometric();
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final pin = await AppLockDialogs.createPin(context, ref);
    if (pin != null) {
      await controller.setPin(pin);
    }
  }

  Future<void> _disable(BuildContext context, WidgetRef ref) async {
    if (await AppLockDialogs.confirmCurrent(context, ref)) {
      await ref.read(appLockControllerProvider.notifier).disable();
    }
  }

  Future<void> _switchMethod(
    BuildContext context,
    WidgetRef ref,
    AppLockMethod target,
  ) async {
    final reason = AppLocalizations.of(context).appLockReasonEnable;
    if (target == ref.read(appLockControllerProvider).method ||
        !await AppLockDialogs.confirmCurrent(context, ref)) {
      return;
    }
    final controller = ref.read(appLockControllerProvider.notifier);
    if (target == AppLockMethod.pin) {
      if (!context.mounted) {
        return;
      }
      final pin = await AppLockDialogs.createPin(context, ref);
      if (pin != null) {
        await controller.setPin(pin);
      }
    } else if (await ref.read(deviceAuthProvider).authenticate(
          reason: reason,
          biometricOnly: true,
        )) {
      await controller.enableBiometric();
    }
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    if (!await AppLockDialogs.confirmCurrent(context, ref) ||
        !context.mounted) {
      return;
    }
    final pin = await AppLockDialogs.createPin(context, ref);
    if (pin != null) {
      await ref.read(appLockControllerProvider.notifier).setPin(pin);
    }
  }
}
