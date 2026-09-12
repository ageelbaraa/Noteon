import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

/// Classifies database open failures for diagnostics without leaking user paths.
abstract final class DatabaseOpenFailure {
  const DatabaseOpenFailure._();

  /// Short, non-sensitive code safe to show in release UI.
  static String codeFor(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('no such file') ||
        text.contains('enoent') ||
        text.contains('not a directory') ||
        (text.contains('directory') && text.contains('exist'))) {
      return 'DB_PATH';
    }
    if (text.contains('isar core') ||
        text.contains('initializeisar') ||
        text.contains('libisar') ||
        text.contains('failed to load') ||
        text.contains('dynamic library')) {
      return 'DB_NATIVE';
    }
    if (text.contains('schema') || text.contains('migration')) {
      return 'DB_SCHEMA';
    }
    if (error is IsarError || text.contains('isar')) {
      return 'DB_ISAR';
    }
    return 'DB_UNKNOWN';
  }

  /// Detail shown only outside release builds (debug/profile).
  static String? debugDetail(Object error, StackTrace stack) {
    if (kReleaseMode) {
      return null;
    }
    final frames = stack.toString().split('\n').take(8).join('\n');
    return '${error.runtimeType}: $error\n\n$frames';
  }
}
