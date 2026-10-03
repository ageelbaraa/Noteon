import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/l10n/app_localizations.dart';
import 'package:noteon/core/providers/app_lock_providers.dart';
import 'package:noteon/core/providers/settings_providers.dart';
import 'package:noteon/features/settings/presentation/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lock_test.dart' show FakeDeviceAuth;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Locale locale) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceAuthProvider.overrideWithValue(FakeDeviceAuth()),
          packageInfoProvider.overrideWith(
            (ref) async => PackageInfo(
              appName: 'Noteon',
              packageName: 'com.noteon.app',
              version: '1.0.0',
              buildNumber: '19',
            ),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows version and build number from package info', (t) async {
    await pump(t, const Locale('en'));
    await t.scrollUntilVisible(find.text('Version 1.0.0 (build 19)'), 300);
    expect(find.text('Version 1.0.0 (build 19)'), findsOneWidget);
  });

  testWidgets('shows version and build number in Arabic', (t) async {
    await pump(t, const Locale('ar'));
    await t.scrollUntilVisible(find.text('الإصدار 1.0.0 (البناء 19)'), 300);
    expect(find.text('الإصدار 1.0.0 (البناء 19)'), findsOneWidget);
  });

  testWidgets('profile name can be set and is shown', (t) async {
    await pump(t, const Locale('en'));
    expect(find.text('Add your name'), findsOneWidget);

    await t.tap(find.text('Add your name'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Baraa');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(find.text('Baraa'), findsOneWidget);
    expect(find.text('Add your name'), findsNothing);
  });
}
