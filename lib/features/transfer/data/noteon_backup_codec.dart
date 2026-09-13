import 'dart:convert';
import 'dart:typed_data';

import '../domain/backup_models.dart';

/// Binary container for an encrypted Noteon backup (`.noteonbak`).
///
/// Layout:
/// - magic `NOTEONBAK` (9 bytes)
/// - version `uint8`
/// - header length `uint32` big-endian
/// - header JSON (UTF-8)
/// - AES-GCM ciphertext || 16-byte MAC
abstract final class NoteonBackupCodec {
  static const magic = 'NOTEONBAK';
  static const currentVersion = 1;
  static const magicBytes = [78, 79, 84, 69, 79, 78, 66, 65, 75]; // NOTEONBAK

  static Uint8List encode({
    required Map<String, Object?> header,
    required Uint8List ciphertextWithMac,
    int version = currentVersion,
  }) {
    final headerBytes = utf8.encode(jsonEncode(header));
    final builder = BytesBuilder(copy: false);
    builder.add(magicBytes);
    builder.addByte(version);
    builder.add(_uint32Be(headerBytes.length));
    builder.add(headerBytes);
    builder.add(ciphertextWithMac);
    return builder.toBytes();
  }

  static NoteonBackupFile decode(Uint8List bytes) {
    if (bytes.length < magicBytes.length + 1 + 4) {
      throw const BackupException(BackupErrorCode.invalidFormat);
    }

    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) {
        throw const BackupException(BackupErrorCode.invalidFormat);
      }
    }

    final version = bytes[magicBytes.length];
    if (version != currentVersion) {
      throw BackupException(
        BackupErrorCode.unsupportedVersion,
        'version=$version',
      );
    }

    final headerLengthOffset = magicBytes.length + 1;
    final headerLength = _readUint32Be(bytes, headerLengthOffset);
    final headerStart = headerLengthOffset + 4;
    final headerEnd = headerStart + headerLength;
    if (headerLength <= 0 || headerEnd > bytes.length) {
      throw const BackupException(BackupErrorCode.invalidFormat);
    }

    final headerJson = utf8.decode(bytes.sublist(headerStart, headerEnd));
    late final Map<String, Object?> header;
    try {
      final decoded = jsonDecode(headerJson);
      if (decoded is! Map) {
        throw const BackupException(BackupErrorCode.invalidFormat);
      }
      header = decoded.cast<String, Object?>();
    } catch (e) {
      if (e is BackupException) rethrow;
      throw const BackupException(BackupErrorCode.invalidFormat);
    }

    final ciphertext = bytes.sublist(headerEnd);
    if (ciphertext.length < 16) {
      throw const BackupException(BackupErrorCode.corruptPayload);
    }

    return NoteonBackupFile(
      version: version,
      header: header,
      ciphertextWithMac: Uint8List.fromList(ciphertext),
    );
  }

  static Uint8List _uint32Be(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);
  }

  static int _readUint32Be(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}

class NoteonBackupFile {
  const NoteonBackupFile({
    required this.version,
    required this.header,
    required this.ciphertextWithMac,
  });

  final int version;
  final Map<String, Object?> header;
  final Uint8List ciphertextWithMac;
}
