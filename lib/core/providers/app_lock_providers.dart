import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/app_lock_store.dart';
import '../security/device_auth.dart';
import '../security/pin_hasher.dart';
import 'crypto_providers.dart';
import 'settings_providers.dart';

export '../security/app_lock_store.dart' show AppLockMethod;

/// Tunable lock behaviour (overridden in tests).
class AppLockConfig {
  const AppLockConfig({
    this.gracePeriod = const Duration(minutes: 1),
    this.maxAttempts = 5,
    this.lockoutDuration = const Duration(seconds: 30),
    this.pinLength = 6,
  });

  final Duration gracePeriod;
  final int maxAttempts;
  final Duration lockoutDuration;
  final int pinLength;
}

final appLockConfigProvider = Provider<AppLockConfig>((ref) {
  return const AppLockConfig();
});

final appLockClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final appLockStoreProvider = Provider<AppLockStore>((ref) {
  return AppLockStore(ref.watch(sharedPreferencesProvider));
});

final deviceAuthProvider = Provider<DeviceAuth>((ref) => LocalDeviceAuth());

final pinHasherProvider = Provider<PinHasher>((ref) {
  return PinHasher(ref.watch(noteCryptoServiceProvider));
});

/// Lets the lock gate (above the navigator) open dialogs on the app navigator.
final appNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

enum PinCheck { ok, wrong, lockedOut }

class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.method,
    required this.locked,
    this.lockoutUntil,
    this.promptNewPin = false,
  });

  final bool enabled;
  final AppLockMethod method;
  final bool locked;

  /// While in the future, PIN entry is paused.
  final DateTime? lockoutUntil;

  /// Set after Forgot PIN reset: the user should choose a new PIN.
  final bool promptNewPin;

  AppLockState copyWith({
    bool? enabled,
    AppLockMethod? method,
    bool? locked,
    Object? lockoutUntil = _keep,
    bool? promptNewPin,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      method: method ?? this.method,
      locked: locked ?? this.locked,
      lockoutUntil: identical(lockoutUntil, _keep)
          ? this.lockoutUntil
          : lockoutUntil as DateTime?,
      promptNewPin: promptNewPin ?? this.promptNewPin,
    );
  }

  static const _keep = Object();
}

/// Owns the optional app lock: setup, locking rules, PIN checks, recovery.
class AppLockController extends Notifier<AppLockState> {
  DateTime? _backgroundedAt;
  bool _authInFlight = false;

  AppLockStore get _store => ref.read(appLockStoreProvider);
  AppLockConfig get _config => ref.read(appLockConfigProvider);
  DateTime _now() => ref.read(appLockClockProvider)();

  @override
  AppLockState build() {
    final store = ref.watch(appLockStoreProvider);
    // Every cold start begins locked when the lock is on.
    return AppLockState(
      enabled: store.enabled,
      method: store.method,
      locked: store.enabled,
      lockoutUntil: store.lockoutUntil,
    );
  }

  int get pinLength => _config.pinLength;

  /// Remaining PIN pause, or null when entry is allowed.
  Duration? lockoutRemaining() {
    final until = state.lockoutUntil;
    if (until == null) {
      return null;
    }
    final left = until.difference(_now());
    return left > Duration.zero ? left : null;
  }

  Future<void> enableBiometric() async {
    await _store.clearPin();
    await _store.writeEnabled(true, AppLockMethod.biometric);
    state = state.copyWith(
      enabled: true,
      method: AppLockMethod.biometric,
      locked: false,
    );
  }

  /// Enables the lock in PIN mode, or replaces the PIN when already on.
  Future<void> setPin(String pin) async {
    await _store.writePin(await ref.read(pinHasherProvider).hash(pin));
    await _store.writeEnabled(true, AppLockMethod.pin);
    await _resetAttempts();
    state = state.copyWith(
      enabled: true,
      method: AppLockMethod.pin,
      locked: false,
      promptNewPin: false,
    );
  }

  Future<void> disable() async {
    await _store.clearPin();
    await _store.writeEnabled(false, state.method);
    await _resetAttempts();
    state = state.copyWith(enabled: false, locked: false);
  }

  void dismissNewPinPrompt() {
    state = state.copyWith(promptNewPin: false);
  }

  Future<void> _resetAttempts() async {
    await _store.writeAttempts(0, null);
    state = state.copyWith(lockoutUntil: null);
  }

  /// Checks [pin] against the stored hash, counting failures in a row.
  Future<PinCheck> verifyPin(String pin) async {
    if (lockoutRemaining() != null) {
      return PinCheck.lockedOut;
    }
    final stored = _store.readPin();
    if (stored == null) {
      return PinCheck.wrong;
    }
    if (await ref.read(pinHasherProvider).verify(pin, stored)) {
      await _resetAttempts();
      return PinCheck.ok;
    }
    final failed = _store.failedAttempts + 1;
    if (failed >= _config.maxAttempts) {
      final until = _now().add(_config.lockoutDuration);
      await _store.writeAttempts(0, until);
      state = state.copyWith(lockoutUntil: until);
      return PinCheck.lockedOut;
    }
    await _store.writeAttempts(failed, null);
    return PinCheck.wrong;
  }

  Future<PinCheck> unlockWithPin(String pin) async {
    final result = await verifyPin(pin);
    if (result == PinCheck.ok) {
      state = state.copyWith(locked: false);
    }
    return result;
  }

  /// Shows the system prompt (biometrics, device screen lock as fallback).
  Future<bool> unlockWithDevice(String reason) async {
    if (_authInFlight) {
      return false;
    }
    _authInFlight = true;
    try {
      final ok = await ref
          .read(deviceAuthProvider)
          .authenticate(reason: reason);
      if (ok) {
        state = state.copyWith(locked: false);
      }
      return ok;
    } finally {
      _authInFlight = false;
    }
  }

  /// Forgot PIN: confirm with the device screen lock, then turn the lock off
  /// and ask for a new PIN. Returns false when there is no screen lock or the
  /// user did not confirm.
  Future<bool> resetPinWithDevice(String reason) async {
    final auth = ref.read(deviceAuthProvider);
    if (!(await auth.capabilities()).hasScreenLock) {
      return false;
    }
    if (!await auth.authenticate(reason: reason)) {
      return false;
    }
    await disable();
    state = state.copyWith(promptNewPin: true);
    return true;
  }

  Future<bool> deviceHasScreenLock() async {
    return (await ref.read(deviceAuthProvider).capabilities()).hasScreenLock;
  }

  void onBackgrounded() {
    _backgroundedAt ??= _now();
  }

  void onForegrounded() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || !state.enabled || state.locked) {
      return;
    }
    if (_now().difference(since) >= _config.gracePeriod) {
      state = state.copyWith(locked: true);
    }
  }

  /// Turns the lock off when it can no longer be used, so the user is never
  /// locked out: biometric mode after every biometric and the screen lock are
  /// removed, or PIN mode with no stored PIN.
  Future<void> revalidate() async {
    if (!state.enabled) {
      return;
    }
    final usable = state.method == AppLockMethod.pin
        ? _store.readPin() != null
        : (await ref.read(deviceAuthProvider).capabilities()).hasScreenLock;
    if (!usable && state.enabled) {
      await disable();
    }
  }
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
