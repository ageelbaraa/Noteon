import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/crypto/note_crypto_service.dart';
import 'package:noteon/core/l10n/app_localizations.dart';
import 'package:noteon/core/providers/app_lock_providers.dart';
import 'package:noteon/core/providers/crypto_providers.dart';
import 'package:noteon/core/providers/settings_providers.dart';
import 'package:noteon/features/app_lock/presentation/app_lock_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lock_test.dart' show FakeDeviceAuth;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDeviceAuth device;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    device = FakeDeviceAuth();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceAuthProvider.overrideWithValue(device),
          appLockConfigProvider.overrideWithValue(
            const AppLockConfig(pinLength: 4, maxAttempts: 2),
          ),
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

    // Set a PIN in one session; the widget tree below is a cold start.
    await tester.runAsync(
      () => makeContainer()
          .read(appLockControllerProvider.notifier)
          .setPin('1234'),
    );
    final container = makeContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: container.read(appNavigatorKeyProvider),
          locale: locale,
          themeMode: themeMode,
          darkTheme: ThemeData.dark(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => AppLockGate(child: child!),
          home: const Scaffold(body: Text('secret note')),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> enter(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }

  testWidgets('lock screen covers content from the first frame',
      (tester) async {
    await pump(tester);
    expect(find.text('Noteon is locked'), findsOneWidget);
    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('secret note').hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('secret note'), findsNothing);
  });

  testWidgets('wrong PIN gives feedback, repeated wrong PINs show a countdown',
      (tester) async {
    await pump(tester);

    await enter(tester, '0000');
    expect(find.text('Wrong PIN'), findsOneWidget);
    expect(find.text('Noteon is locked'), findsOneWidget);

    await enter(tester, '0000');
    expect(find.textContaining('Try again in'), findsOneWidget);

    // Input is paused: the right PIN does not unlock.
    await enter(tester, '1234');
    expect(find.text('Noteon is locked'), findsOneWidget);
  });

  testWidgets('right PIN reveals the app', (tester) async {
    await pump(tester);
    await enter(tester, '1234');
    expect(find.text('Noteon is locked'), findsNothing);
    expect(find.text('secret note'), findsOneWidget);
  });

  testWidgets('works in Arabic (RTL) and dark theme', (tester) async {
    await pump(tester, locale: const Locale('ar'), themeMode: ThemeMode.dark);
    expect(find.text('Noteon مقفل'), findsOneWidget);
    expect(find.text('نسيت رمز PIN؟'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Forgot PIN without a screen lock explains recovery',
      (tester) async {
    device.hasScreenLock = false;
    await pump(tester);

    await tester.tap(find.text('Forgot PIN?'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Can’t reset the PIN'), findsOneWidget);
    expect(find.textContaining('clear Noteon’s app data'), findsOneWidget);
    expect(find.text('Noteon is locked'), findsOneWidget);
  });

  testWidgets('Forgot PIN with a screen lock unlocks and turns the lock off',
      (tester) async {
    final container = await pump(tester);

    await tester.tap(find.text('Forgot PIN?'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Noteon is locked'), findsNothing);
    expect(container.read(appLockControllerProvider).enabled, isFalse);
    // The new-PIN dialog is offered.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Set a new PIN'), findsOneWidget);
  });
}
