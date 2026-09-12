import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/app_settings_store.dart';

export '../settings/app_settings_store.dart' show AppThemeMode, AppSettingsStore;

/// Overridden in [main] after [SharedPreferences.getInstance].
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be provided in main');
});

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsStore(ref.watch(sharedPreferencesProvider));
});

/// Holds the user's preferred appearance mode (persisted).
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    return ref.watch(appSettingsStoreProvider).readThemeMode();
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    await ref.read(appSettingsStoreProvider).writeThemeMode(mode);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);

/// Holds the user's preferred app locale (persisted).
/// `null` follows the device locale (en / ar).
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    return ref.watch(appSettingsStoreProvider).readLocale();
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    await ref.read(appSettingsStoreProvider).writeLocale(locale);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
