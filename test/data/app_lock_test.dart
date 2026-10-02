import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/crypto/note_crypto_service.dart';
import 'package:noteon/core/providers/app_lock_providers.dart';
import 'package:noteon/core/providers/crypto_providers.dart';
import 'package:noteon/core/providers/settings_providers.dart';
import 'package:noteon/core/security/app_lock_store.dart';
import 'package:noteon/core/security/device_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDeviceAuth implements DeviceAuth {
  bool hasBiometrics = true;
  bool hasScreenLock = true;
  bool result = true;
  bool? lastBiometricOnly;
  int prompts = 0;

  @override
  Future<DeviceAuthCapabilities> capabilities() async => DeviceAuthCapabilities(
        hasBiometrics: hasBiometrics,
        hasScreenLock: hasScreenLock,
      );

  @override
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    prompts++;
    lastBiometricOnly = biometricOnly;
    return result;
  }
}

void main() {
  late FakeDeviceAuth device;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    device = FakeDeviceAuth();
    now = DateTime(2026, 1, 1, 12);
  });

  Future<ProviderContainer> makeContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceAuthProvider.overrideWithValue(device),
        appLockClockProvider.overrideWithValue(() => now),
        noteCryptoServiceProvider.overrideWithValue(
          NoteCryptoService(
            config: const NoteCryptoConfig(pbkdf2Iterations: 1000),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('lock is off by default', () async {
    final container = await makeContainer();
    final state = container.read(appLockControllerProvider);
    expect(state.enabled, isFalse);
    expect(state.locked, isFalse);
  });

  test('enabling biometrics does not lock and stores no PIN', () async {
    final container = await makeContainer();
    await container.read(appLockControllerProvider.notifier).enableBiometric();
    final state = container.read(appLockControllerProvider);
    expect(state.enabled, isTrue);
    expect(state.method, AppLockMethod.biometric);
    expect(state.locked, isFalse);
    expect(container.read(appLockStoreProvider).readPin(), isNull);
  });

  test('PIN is stored as a salted hash, with a new salt per PIN', () async {
    final container = await makeContainer();
    final controller = container.read(appLockControllerProvider.notifier);
    final store = container.read(appLockStoreProvider);

    await controller.setPin('123456');
    final first = store.readPin()!;
    await controller.setPin('123456');
    final second = store.readPin()!;

    expect(first.salt, isNot(second.salt));
    expect(first.hash, isNot(second.hash));
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      expect(prefs.get(key).toString(), isNot(contains('123456')));
    }
  });

  test('cold start is locked when the lock is on', () async {
    final first = await makeContainer();
    await first.read(appLockControllerProvider.notifier).setPin('123456');
    expect(first.read(appLockControllerProvider).locked, isFalse);

    final second = await makeContainer();
    final state = second.read(appLockControllerProvider);
    expect(state.enabled, isTrue);
    expect(state.locked, isTrue);
    expect(state.method, AppLockMethod.pin);
  });

  test('locks after the grace period in background, not after a short one',
      () async {
    final container = await makeContainer();
    final controller = container.read(appLockControllerProvider.notifier);
    await controller.enableBiometric();

    controller.onBackgrounded();
    now = now.add(const Duration(seconds: 59));
    controller.onForegrounded();
    expect(container.read(appLockControllerProvider).locked, isFalse);

    controller.onBackgrounded();
    now = now.add(const Duration(minutes: 1));
    controller.onForegrounded();
    expect(container.read(appLockControllerProvider).locked, isTrue);
  });

  test('never locks in the background when the lock is off', () async {
    final container = await makeContainer();
    final controller = container.read(appLockControllerProvider.notifier);
    controller.onBackgrounded();
    now = now.add(const Duration(hours: 1));
    controller.onForegrounded();
    expect(container.read(appLockControllerProvider).locked, isFalse);
  });

  test('wrong PIN is rejected, right PIN unlocks', () async {
    final first = await makeContainer();
    await first.read(appLockControllerProvider.notifier).setPin('123456');
    final container = await makeContainer();
    final controller = container.read(appLockControllerProvider.notifier);

    expect(await controller.unlockWithPin('000000'), PinCheck.wrong);
    expect(container.read(appLockControllerProvider).locked, isTrue);
    expect(await controller.unlockWithPin('123456'), PinCheck.ok);
    expect(container.read(appLockControllerProvider).locked, isFalse);
  });

  test('repeated wrong PINs pause entry, then allow it again', () async {
    final first = await makeContainer();
    await first.read(appLockControllerProvider.notifier).setPin('123456');
    final container = await makeContainer();
    final controller = container.read(appLockControllerProvider.notifier);

    for (var i = 0; i < 4; i++) {
      expect(await controller.unlockWithPin('000000'), PinCheck.wrong);
    }
    expect(controller.lockoutRemaining(), isNull);
    expect(await controller.unlockWithPin('000000'), PinCheck.lockedOut);
    expect(controller.lockoutRemaining(), const Duration(seconds: 30));

    // Even the right PIN is refused during the pause.
    expect(await controller.unlockWithPin('123456'), PinCheck.lockedOut);
    expect(container.read(appLockControllerProvider).locked, isTrue);

    // The pause survives a restart.
    final restarted = await makeContainer();
    expect(
      restarted.read(appLockControllerProvider.notifier).lockoutRemaining(),
      isNotNull,
    );

    now = now.add(const Duration(seconds: 30));
    expect(controller.lockoutRemaining(), isNull);
    expect(await controller.unlockWithPin('123456'), PinCheck.ok);
  });

  test('device prompt unlocks in biometric mode', () async {
    final first = await makeContainer();
    await first.read(appLockControllerProvider.notifier).enableBiometric();
    final container = await makeContainer();
    final controller = container.read(appLockControllerProvider.notifier);

    device.result = false;
    expect(await controller.unlockWithDevice('r'), isFalse);
    expect(container.read(appLockControllerProvider).locked, isTrue);

    device.result = true;
    expect(await controller.unlockWithDevice('r'), isTrue);
    expect(container.read(appLockControllerProvider).locked, isFalse);
    expect(device.lastBiometricOnly, isFalse);
  });

  test('disabling clears the PIN and resets attempts', () async {
    final container = await makeContainer();
    final controller = container.read(appLockControllerProvider.notifier);
    await controller.setPin('123456');
    await controller.verifyPin('000000');
    await controller.disable();

    expect(container.read(appLockControllerProvider).enabled, isFalse);
    final store = container.read(appLockStoreProvider);
    expect(store.readPin(), isNull);
    expect(store.failedAttempts, 0);
  });

  group('Forgot PIN', () {
    test('device screen lock unlocks, turns the lock off and asks for a PIN',
        () async {
      final first = await makeContainer();
      await first.read(appLockControllerProvider.notifier).setPin('123456');
      final container = await makeContainer();
      final controller = container.read(appLockControllerProvider.notifier);

      expect(await controller.resetPinWithDevice('r'), isTrue);
      final state = container.read(appLockControllerProvider);
      expect(state.locked, isFalse);
      expect(state.enabled, isFalse);
      expect(state.promptNewPin, isTrue);
      expect(container.read(appLockStoreProvider).readPin(), isNull);
    });

    test('without a screen lock nothing changes', () async {
      final first = await makeContainer();
      await first.read(appLockControllerProvider.notifier).setPin('123456');
      final container = await makeContainer();
      final controller = container.read(appLockControllerProvider.notifier);
      device.hasScreenLock = false;

      expect(await controller.deviceHasScreenLock(), isFalse);
      expect(await controller.resetPinWithDevice('r'), isFalse);
      expect(device.prompts, 0);
      final state = container.read(appLockControllerProvider);
      expect(state.locked, isTrue);
      expect(state.enabled, isTrue);
    });

    test('a cancelled device prompt keeps the lock', () async {
      final first = await makeContainer();
      await first.read(appLockControllerProvider.notifier).setPin('123456');
      final container = await makeContainer();
      device.result = false;
      expect(
        await container
            .read(appLockControllerProvider.notifier)
            .resetPinWithDevice('r'),
        isFalse,
      );
      expect(container.read(appLockControllerProvider).enabled, isTrue);
    });
  });

  group('revalidate', () {
    test('turns biometric lock off when biometrics and screen lock are gone',
        () async {
      final first = await makeContainer();
      await first.read(appLockControllerProvider.notifier).enableBiometric();
      final container = await makeContainer();
      device
        ..hasBiometrics = false
        ..hasScreenLock = false;

      await container.read(appLockControllerProvider.notifier).revalidate();
      final state = container.read(appLockControllerProvider);
      expect(state.enabled, isFalse);
      expect(state.locked, isFalse);
    });

    test('keeps biometric lock while a screen lock remains', () async {
      final first = await makeContainer();
      await first.read(appLockControllerProvider.notifier).enableBiometric();
      final container = await makeContainer();
      device.hasBiometrics = false;

      await container.read(appLockControllerProvider.notifier).revalidate();
      expect(container.read(appLockControllerProvider).enabled, isTrue);
    });

    test('PIN lock is unaffected by device changes', () async {
      final first = await makeContainer();
      await first.read(appLockControllerProvider.notifier).setPin('123456');
      final container = await makeContainer();
      device
        ..hasBiometrics = false
        ..hasScreenLock = false;

      await container.read(appLockControllerProvider.notifier).revalidate();
      expect(container.read(appLockControllerProvider).enabled, isTrue);
    });
  });

  test('store defaults', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppLockStore(prefs);
    expect(store.enabled, isFalse);
    expect(store.failedAttempts, 0);
    expect(store.lockoutUntil, isNull);
  });
}
