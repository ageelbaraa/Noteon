import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/database_open_failure.dart';
import 'core/database/isar_database.dart';
import 'core/providers/settings_providers.dart';
import 'features/home/presentation/database_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  try {
    await IsarDatabase.open();
  } catch (error, stack) {
    final code = DatabaseOpenFailure.codeFor(error);
    final detail = DatabaseOpenFailure.debugDetail(error, stack);

    // Always log a non-path-heavy breadcrumb for release tooling / logcat.
    debugPrint('Noteon database open failed [$code]: ${error.runtimeType}');
    if (detail != null) {
      debugPrint(detail);
    }

    runApp(
      DatabaseErrorApp(
        failureCode: code,
        debugDetail: detail,
        onRetry: () => _retryLaunch(prefs),
      ),
    );
    return;
  }

  _runNoteon(prefs);
}

void _runNoteon(SharedPreferences prefs) {
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const NoteonApp(),
    ),
  );
}

Future<void> _retryLaunch(SharedPreferences prefs) async {
  try {
    await IsarDatabase.open();
    _runNoteon(prefs);
  } catch (error, stack) {
    final code = DatabaseOpenFailure.codeFor(error);
    final detail = DatabaseOpenFailure.debugDetail(error, stack);
    debugPrint('Noteon database retry failed [$code]: ${error.runtimeType}');
    if (detail != null) {
      debugPrint(detail);
    }
    runApp(
      DatabaseErrorApp(
        failureCode: code,
        debugDetail: detail,
        onRetry: () => _retryLaunch(prefs),
      ),
    );
  }
}
