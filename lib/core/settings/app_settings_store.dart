import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported appearance modes for Noteon.
enum AppThemeMode {
  system,
  light,
  dark,
}

/// How notes are laid out on the home screen.
enum NotesViewMode {
  list,
  grid,
}

/// Paper pattern behind the note editor body.
enum NotePageBackground {
  plain,
  lined,
  grid,
}

/// Local persistence for theme, language, and notes view preferences.
class AppSettingsStore {
  AppSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const themeKey = 'noteon.theme_mode';
  static const localeKey = 'noteon.locale';
  static const notesViewModeKey = 'noteon.notes_view_mode';
  static const notePageBackgroundKey = 'noteon.note_page_background';

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

  NotesViewMode readNotesViewMode() {
    final raw = _prefs.getString(notesViewModeKey);
    if (raw == null) {
      return NotesViewMode.list;
    }
    for (final mode in NotesViewMode.values) {
      if (mode.name == raw) {
        return mode;
      }
    }
    return NotesViewMode.list;
  }

  Future<void> writeNotesViewMode(NotesViewMode mode) {
    return _prefs.setString(notesViewModeKey, mode.name);
  }

  NotePageBackground readNotePageBackground() {
    final raw = _prefs.getString(notePageBackgroundKey);
    if (raw == null) {
      return NotePageBackground.plain;
    }
    for (final mode in NotePageBackground.values) {
      if (mode.name == raw) {
        return mode;
      }
    }
    return NotePageBackground.plain;
  }

  Future<void> writeNotePageBackground(NotePageBackground mode) {
    return _prefs.setString(notePageBackgroundKey, mode.name);
  }
}
