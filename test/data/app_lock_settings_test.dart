import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/crypto/note_crypto_service.dart';
import 'package:noteon/core/l10n/app_localizations.dart';
import 'package:noteon/core/providers/app_lock_providers.dart';
import 'package:noteon/core/providers/crypto_providers.dart';
import 'package:noteon/core/providers/settings_providers.dart';
import 'package:noteon/features/app_lock/presentation/app_lock_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lock_test.dart' show FakeDeviceAuth;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDeviceAuth device;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    device = FakeDeviceAuth();
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceAuthProvider.overrideWithValue(device),
        appLockConfigProvider.overrideWithValue(
          const AppLockConfig(pinLength: 4),
        ),
        noteCryptoServiceProvider.overrideWithValue(
          NoteCryptoService(
            config: const NoteCryptoConfig(pbkdf2Iterations: 1000),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: AppLockSection()),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> enter(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await settle(tester);
  }

  testWidgets('turning on with biometrics confirms once, biometric only',
      (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(device.prompts, 1);
    expect(device.lastBiometricOnly, isTrue);
    final state = container.read(appLockControllerProvider);
    expect(state.enabled, isTrue);
    expect(state.method, AppLockMethod.biometric);
    expect(find.text('Unlock with'), findsOneWidget);
  });

  testWidgets('a cancelled biometric prompt leaves the lock off',
      (tester) async {
    final container = await pump(tester);
    device.result = false;
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(container.read(appLockControllerProvider).enabled, isFalse);
  });

  testWidgets('without biometrics, turning on asks for the PIN twice',
      (tester) async {
    device.hasBiometrics = false;
    final container = await pump(tester);
    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(find.text('Create a PIN'), findsOneWidget);
    await enter(tester, '1234');
    expect(find.text('Enter the PIN again'), findsOneWidget);
    await enter(tester, '1234');

    final state = container.read(appLockControllerProvider);
    expect(state.enabled, isTrue);
    expect(state.method, AppLockMethod.pin);
    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.text('Unlock with'), findsNothing);
  });

  testWidgets('mismatched confirmation does not enable the lock',
      (tester) async {
    device.hasBiometrics = false;
    final container = await pump(tester);
    await tester.tap(find.byType(Switch));
    await settle(tester);
    await enter(tester, '1234');
    await enter(tester, '4321');

    expect(find.text('The PINs don’t match. Try again.'), findsOneWidget);
    expect(container.read(appLockControllerProvider).enabled, isFalse);
  });

  testWidgets('turning off needs the current unlock (biometric)',
      (tester) async {
    final container = await pump(tester);
    await container.read(appLockControllerProvider.notifier).enableBiometric();
    await tester.pump();

    device.result = false;
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(container.read(appLockControllerProvider).enabled, isTrue);

    device.result = true;
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(container.read(appLockControllerProvider).enabled, isFalse);
  });

  testWidgets('turning off and changing the PIN need the current PIN',
      (tester) async {
    device.hasBiometrics = false;
    final container = await pump(tester);
    await tester.runAsync(
      () => container.read(appLockControllerProvider.notifier).setPin('1234'),
    );
    await tester.pump();

    // Wrong PIN: lock stays on.
    await tester.tap(find.byType(Switch));
    await settle(tester);
    await enter(tester, '0000');
    expect(find.text('Wrong PIN'), findsOneWidget);
    expect(container.read(appLockControllerProvider).enabled, isTrue);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    // Change PIN: current PIN, then the new one twice.
    await tester.tap(find.text('Change PIN'));
    await settle(tester);
    await enter(tester, '1234');
    await enter(tester, '5555');
    await enter(tester, '5555');
    final store = container.read(appLockStoreProvider);
    expect(
      await tester.runAsync(
        () => container.read(pinHasherProvider).verify('5555', store.readPin()!),
      ),
      isTrue,
    );

    // Turn off with the right PIN.
    await tester.tap(find.byType(Switch));
    await settle(tester);
    await enter(tester, '5555');
    expect(container.read(appLockControllerProvider).enabled, isFalse);
  });
}
