import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noteon/core/crypto/note_crypto_service.dart';

void main() {
  late NoteCryptoService crypto;

  setUp(() {
    crypto = NoteCryptoService(
      config: const NoteCryptoConfig(pbkdf2Iterations: 1000),
    );
  });

  test('password derives a stable key for the same salt', () async {
    final salt = crypto.generateSalt();
    final key1 = await crypto.deriveKey(password: 'secret-pass', salt: salt);
    final key2 = await crypto.deriveKey(password: 'secret-pass', salt: salt);
    final bytes1 = await key1.extractBytes();
    final bytes2 = await key2.extractBytes();
    expect(bytes1, bytes2);
    expect(bytes1, hasLength(32));
  });

  test('different salts produce different keys', () async {
    final key1 = await crypto.deriveKey(
      password: 'secret-pass',
      salt: crypto.generateSalt(),
    );
    final key2 = await crypto.deriveKey(
      password: 'secret-pass',
      salt: crypto.generateSalt(),
    );
    expect(await key1.extractBytes(), isNot(await key2.extractBytes()));
  });

  test('encrypt then decrypt restores UTF-8 payload', () async {
    final salt = crypto.generateSalt();
    final key = await crypto.deriveKey(password: 'correct horse', salt: salt);
    final sealed = await crypto.encryptUtf8(
      clearText: '{"hello":"world"}',
      key: key,
    );
    final clear = await crypto.decryptUtf8(
      ciphertextWithMac: sealed.ciphertextWithMac,
      nonce: sealed.nonce,
      key: key,
    );
    expect(clear, '{"hello":"world"}');
  });

  test('wrong password fails verifier check', () async {
    final salt = crypto.generateSalt();
    final key = await crypto.deriveKey(password: 'right-password', salt: salt);
    final verifier = await crypto.createPasswordVerifier(key);

    final ok = await crypto.verifyPassword(
      password: 'right-password',
      salt: salt,
      storedVerifier: verifier,
    );
    final bad = await crypto.verifyPassword(
      password: 'wrong-password',
      salt: salt,
      storedVerifier: verifier,
    );
    expect(ok, isTrue);
    expect(bad, isFalse);
  });

  test('ciphertext tampering is detected by AES-GCM', () async {
    final salt = crypto.generateSalt();
    final key = await crypto.deriveKey(password: 'pw', salt: salt);
    final sealed = await crypto.encryptBytes(
      clearBytes: utf8.encode('sensitive'),
      key: key,
    );
    final tampered = Uint8List.fromList(sealed.ciphertextWithMac);
    tampered[0] = tampered[0] ^ 0xff;

    expect(
      () => crypto.decryptBytes(
        ciphertextWithMac: tampered,
        nonce: sealed.nonce,
        key: key,
      ),
      throwsA(isA<NoteCryptoException>()),
    );
  });

  test('each encryption uses a unique nonce', () async {
    final salt = crypto.generateSalt();
    final key = await crypto.deriveKey(password: 'pw', salt: salt);
    final a = await crypto.encryptUtf8(clearText: 'one', key: key);
    final b = await crypto.encryptUtf8(clearText: 'one', key: key);
    expect(a.nonce, isNot(b.nonce));
  });

  test('generateSalt returns unique values', () {
    final a = crypto.generateSalt();
    final b = crypto.generateSalt();
    expect(a, isNot(b));
    expect(a, hasLength(16));
  });

  test('constantTimeEquals compares securely by length and content', () {
    expect(crypto.constantTimeEquals([1, 2], [1, 2]), isTrue);
    expect(crypto.constantTimeEquals([1, 2], [1, 3]), isFalse);
    expect(crypto.constantTimeEquals([1, 2], [1]), isFalse);
  });
}
