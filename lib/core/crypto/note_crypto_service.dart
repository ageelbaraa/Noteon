import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Configuration for Noteon per-note cryptography.
class NoteCryptoConfig {
  const NoteCryptoConfig({
    this.pbkdf2Iterations = 120000,
    this.saltLength = 16,
    this.keyBits = 256,
  });

  /// PBKDF2-HMAC-SHA256 iteration count (mobile-balanced).
  final int pbkdf2Iterations;

  final int saltLength;
  final int keyBits;

  static const NoteCryptoConfig defaults = NoteCryptoConfig();
}

/// Result of encrypting a UTF-8 payload with AES-GCM.
class NoteCipherPackage {
  const NoteCipherPackage({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List mac;

  /// Combined ciphertext || mac for compact storage.
  Uint8List get ciphertextWithMac =>
      Uint8List.fromList([...ciphertext, ...mac]);
}

/// Password-based note cryptography: PBKDF2-HMAC-SHA256 + AES-256-GCM.
class NoteCryptoService {
  NoteCryptoService({
    NoteCryptoConfig config = NoteCryptoConfig.defaults,
    Random? random,
  })  : _config = config,
        _random = random ?? Random.secure(),
        _aes = AesGcm.with256bits(),
        _pbkdf2 = Pbkdf2.hmacSha256(
          iterations: config.pbkdf2Iterations,
          bits: config.keyBits,
        ),
        _hmac = Hmac.sha256();

  final NoteCryptoConfig _config;
  final Random _random;
  final AesGcm _aes;
  final Pbkdf2 _pbkdf2;
  final Hmac _hmac;

  static const _verifierMessage = 'noteon-note-v1';

  Uint8List randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  Uint8List generateSalt() => randomBytes(_config.saltLength);

  Future<SecretKey> deriveKey({
    required String password,
    required List<int> salt,
    int? iterations,
  }) {
    final pbkdf2 = (iterations == null ||
            iterations == _config.pbkdf2Iterations)
        ? _pbkdf2
        : Pbkdf2.hmacSha256(
            iterations: iterations,
            bits: _config.keyBits,
          );
    return pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  int get pbkdf2Iterations => _config.pbkdf2Iterations;

  Future<Uint8List> createPasswordVerifier(SecretKey key) async {
    final mac = await _hmac.calculateMac(
      utf8.encode(_verifierMessage),
      secretKey: key,
    );
    return Uint8List.fromList(mac.bytes);
  }

  /// Constant-time equality for MAC/verifier bytes.
  bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Future<bool> verifyPassword({
    required String password,
    required List<int> salt,
    required List<int> storedVerifier,
  }) async {
    final key = await deriveKey(password: password, salt: salt);
    final actual = await createPasswordVerifier(key);
    return constantTimeEquals(actual, storedVerifier);
  }

  Future<NoteCipherPackage> encryptBytes({
    required List<int> clearBytes,
    required SecretKey key,
    List<int>? nonce,
  }) async {
    final usedNonce = nonce ?? _aes.newNonce();
    final box = await _aes.encrypt(
      clearBytes,
      secretKey: key,
      nonce: usedNonce,
    );
    return NoteCipherPackage(
      ciphertext: Uint8List.fromList(box.cipherText),
      nonce: Uint8List.fromList(box.nonce),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  Future<Uint8List> decryptBytes({
    required List<int> ciphertextWithMac,
    required List<int> nonce,
    required SecretKey key,
  }) async {
    if (ciphertextWithMac.length < 16) {
      throw const NoteCryptoException(NoteCryptoErrorCode.missingData);
    }
    final macStart = ciphertextWithMac.length - 16;
    final cipherText = ciphertextWithMac.sublist(0, macStart);
    final macBytes = ciphertextWithMac.sublist(macStart);
    try {
      final clear = await _aes.decrypt(
        SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(macBytes),
        ),
        secretKey: key,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const NoteCryptoException(NoteCryptoErrorCode.authenticationFailed);
    }
  }

  Future<NoteCipherPackage> encryptUtf8({
    required String clearText,
    required SecretKey key,
  }) {
    return encryptBytes(clearBytes: utf8.encode(clearText), key: key);
  }

  Future<String> decryptUtf8({
    required List<int> ciphertextWithMac,
    required List<int> nonce,
    required SecretKey key,
  }) async {
    final bytes = await decryptBytes(
      ciphertextWithMac: ciphertextWithMac,
      nonce: nonce,
      key: key,
    );
    return utf8.decode(bytes);
  }
}

class NoteCryptoException implements Exception {
  const NoteCryptoException(
    this.code, [
    this.debugMessage = '',
  ]);

  final NoteCryptoErrorCode code;

  /// Non-user-facing detail for diagnostics; never log passwords/keys.
  final String debugMessage;

  @override
  String toString() => 'NoteCryptoException(${code.name})';
}

enum NoteCryptoErrorCode {
  incorrectPassword,
  corruptData,
  missingData,
  alreadyLocked,
  notLocked,
  invalidSession,
  passwordTooShort,
  authenticationFailed,
}
