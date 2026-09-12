import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported appearance modes for Noteon.
enum AppThemeMode {
  system,
  light,
  dark,
}

/// Local persistence for theme and language preferences.
class AppSettingsStore {
  AppSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const themeKey = 'noteon.theme_mode';
  static const localeKey = 'noteon.locale';

  AppThemeMode readThemeMode() {
    final raw = _prefs.getString(themeKey);
    if (raw == null) {
      return AppThemeMode.system;
    }
    for (final mode in AppThemeMode.values) {
      if (mode.name == raw) {
        return mode;
      }
    }
    return AppThemeMode.system;
  }

  Future<void> writeThemeMode(AppThemeMode mode) {
    return _prefs.setString(themeKey, mode.name);
  }

  /// `null` means follow the device locale.
  Locale? readLocale() {
    final raw = _prefs.getString(localeKey);
    if (raw == null || raw == 'system') {
      return null;
    }
    if (raw == 'en' || raw == 'ar') {
      return Locale(raw);
    }
    return null;
  }

  Future<void> writeLocale(Locale? locale) {
    final value = locale?.languageCode ?? 'system';
    return _prefs.setString(localeKey, value);
  }
}
