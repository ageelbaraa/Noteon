import 'dart:convert';

import '../crypto/note_crypto_service.dart';

/// Salted PBKDF2 hash of an app-lock PIN. The PIN itself is never stored.
class PinHash {
  const PinHash({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  final List<int> salt;
  final List<int> hash;
  final int iterations;
}

/// Hashes and verifies PINs with a fresh random salt per PIN.
class PinHasher {
  PinHasher(this._crypto);

  final NoteCryptoService _crypto;

  Future<PinHash> hash(String pin) async {
    final salt = _crypto.generateSalt();
    final iterations = _crypto.pbkdf2Iterations;
    final key = await _crypto.deriveKey(
      password: pin,
      salt: salt,
      iterations: iterations,
    );
    return PinHash(
      salt: salt,
      hash: await key.extractBytes(),
      iterations: iterations,
    );
  }

  Future<bool> verify(String pin, PinHash stored) async {
    final key = await _crypto.deriveKey(
      password: pin,
      salt: stored.salt,
      iterations: stored.iterations,
    );
    return _crypto.constantTimeEquals(await key.extractBytes(), stored.hash);
  }

  static String encode(List<int> bytes) => base64Encode(bytes);
  static List<int> decode(String value) => base64Decode(value);
}
