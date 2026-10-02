import 'package:shared_preferences/shared_preferences.dart';

import 'pin_hasher.dart';

enum AppLockMethod { biometric, pin }

/// Persists app-lock settings in app-private storage (shared preferences).
/// Only a salted PBKDF2 hash of the PIN is stored.
class AppLockStore {
  AppLockStore(this._prefs);

  final SharedPreferences _prefs;

  static const enabledKey = 'noteon.app_lock.enabled';
  static const methodKey = 'noteon.app_lock.method';
  static const pinSaltKey = 'noteon.app_lock.pin_salt';
  static const pinHashKey = 'noteon.app_lock.pin_hash';
  static const pinIterationsKey = 'noteon.app_lock.pin_iterations';
  static const failedAttemptsKey = 'noteon.app_lock.failed_attempts';
  static const lockoutUntilKey = 'noteon.app_lock.lockout_until';

  bool get enabled => _prefs.getBool(enabledKey) ?? false;

  AppLockMethod get method {
    return _prefs.getString(methodKey) == AppLockMethod.pin.name
        ? AppLockMethod.pin
        : AppLockMethod.biometric;
  }

  Future<void> writeEnabled(bool value, AppLockMethod method) async {
    await _prefs.setString(methodKey, method.name);
    await _prefs.setBool(enabledKey, value);
  }

  PinHash? readPin() {
    final salt = _prefs.getString(pinSaltKey);
    final hash = _prefs.getString(pinHashKey);
    final iterations = _prefs.getInt(pinIterationsKey);
    if (salt == null || hash == null || iterations == null) {
      return null;
    }
    return PinHash(
      salt: PinHasher.decode(salt),
      hash: PinHasher.decode(hash),
      iterations: iterations,
    );
  }

  Future<void> writePin(PinHash pin) async {
    await _prefs.setString(pinSaltKey, PinHasher.encode(pin.salt));
    await _prefs.setString(pinHashKey, PinHasher.encode(pin.hash));
    await _prefs.setInt(pinIterationsKey, pin.iterations);
  }

  Future<void> clearPin() async {
    await _prefs.remove(pinSaltKey);
    await _prefs.remove(pinHashKey);
    await _prefs.remove(pinIterationsKey);
  }

  int get failedAttempts => _prefs.getInt(failedAttemptsKey) ?? 0;

  DateTime? get lockoutUntil {
    final ms = _prefs.getInt(lockoutUntilKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> writeAttempts(int failed, DateTime? lockoutUntil) async {
    await _prefs.setInt(failedAttemptsKey, failed);
    if (lockoutUntil == null) {
      await _prefs.remove(lockoutUntilKey);
    } else {
      await _prefs.setInt(
        lockoutUntilKey,
        lockoutUntil.millisecondsSinceEpoch,
      );
    }
  }
}
