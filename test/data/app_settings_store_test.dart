import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/settings/app_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists theme mode across store instances', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppSettingsStore(prefs);

    expect(store.readThemeMode(), AppThemeMode.system);
    await store.writeThemeMode(AppThemeMode.dark);

    final reloaded = AppSettingsStore(await SharedPreferences.getInstance());
    expect(reloaded.readThemeMode(), AppThemeMode.dark);
  });

  test('persists locale preference and system sentinel', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppSettingsStore(prefs);

    expect(store.readLocale(), isNull);
    await store.writeLocale(const Locale('ar'));
    expect(store.readLocale()?.languageCode, 'ar');

    await store.writeLocale(null);
    expect(store.readLocale(), isNull);
    expect(prefs.getString(AppSettingsStore.localeKey), 'system');
  });

  test('ignores unknown persisted theme values', () async {
    SharedPreferences.setMockInitialValues({
      AppSettingsStore.themeKey: 'neon',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = AppSettingsStore(prefs);
    expect(store.readThemeMode(), AppThemeMode.system);
  });
}
