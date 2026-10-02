import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// What the device can offer for unlocking.
class DeviceAuthCapabilities {
  const DeviceAuthCapabilities({
    required this.hasBiometrics,
    required this.hasScreenLock,
  });

  /// At least one biometric is enrolled.
  final bool hasBiometrics;

  /// A biometric or a device PIN/pattern/password is set up.
  final bool hasScreenLock;
}

/// Thin seam over the platform biometric / screen-lock prompt.
abstract class DeviceAuth {
  Future<DeviceAuthCapabilities> capabilities();

  /// Shows the system prompt. With [biometricOnly] the device screen lock is
  /// not accepted. Returns false on cancel or failure.
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  });
}

class LocalDeviceAuth implements DeviceAuth {
  LocalDeviceAuth([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<DeviceAuthCapabilities> capabilities() async {
    try {
      final enrolled = await _auth.getAvailableBiometrics();
      final supported = await _auth.isDeviceSupported();
      return DeviceAuthCapabilities(
        hasBiometrics: enrolled.isNotEmpty,
        hasScreenLock: supported || enrolled.isNotEmpty,
      );
    } on PlatformException {
      return const DeviceAuthCapabilities(
        hasBiometrics: false,
        hasScreenLock: false,
      );
    }
  }

  @override
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
      );
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}
