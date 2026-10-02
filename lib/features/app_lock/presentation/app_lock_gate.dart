import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_lock_providers.dart';
import 'app_lock_dialogs.dart';
import 'app_lock_screen.dart';

/// Wraps the app navigator: covers it with [AppLockScreen] while locked and
/// re-locks after the app has spent the grace period in the background.
///
/// Only the UI is gated; background work and notifications are untouched.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Biometric lock must not strand the user if the device lock was removed.
    ref.read(appLockControllerProvider.notifier).revalidate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appLockControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
        controller.onBackgrounded();
      case AppLifecycleState.resumed:
        controller.onForegrounded();
        controller.revalidate();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _maybeOfferNewPin(AppLockState state) {
    if (!state.promptNewPin || state.locked) {
      return;
    }
    final context = ref.read(appNavigatorKeyProvider).currentState?.overlay?.context;
    if (context != null) {
      AppLockDialogs.offerNewPin(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppLockState>(appLockControllerProvider, (_, next) {
      _maybeOfferNewPin(next);
    });
    final locked = ref.watch(appLockControllerProvider.select((s) => s.locked));

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: locked,
          child: ExcludeSemantics(excluding: locked, child: widget.child),
        ),
        if (locked) const AppLockScreen(),
      ],
    );
  }
}
