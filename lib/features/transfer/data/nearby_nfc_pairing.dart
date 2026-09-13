import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../domain/backup_models.dart';
import '../domain/nearby_transfer_models.dart';

/// Android NFC assist for nearby pairing (same metadata as the QR code).
///
/// Writes/reads a short NDEF record to a tag. Does not carry note bytes —
/// only host/port/token/verify so the receiver can download over Wi‑Fi.
/// QR remains the canonical path (required for iOS).
abstract final class NearbyNfcPairing {
  static const mimeType = 'application/vnd.noteon.transfer+json';

  /// NFC assist is Android-first; iOS stays on QR.
  static Future<bool> isAssistAvailable() async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (_) {
      return false;
    }
  }

  static NdefMessage messageFor(NearbyQrPayload payload) {
    final body = utf8.encode(payload.encode());
    return NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(utf8.encode(mimeType)),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(body),
        ),
      ],
    );
  }

  static NearbyQrPayload? payloadFromMessage(NdefMessage? message) {
    if (message == null || message.records.isEmpty) {
      return null;
    }
    for (final record in message.records) {
      final parsed = _tryRecord(record);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static NearbyQrPayload? _tryRecord(NdefRecord record) {
    try {
      if (record.typeNameFormat == TypeNameFormat.media) {
        final type = utf8.decode(record.type);
        if (type == mimeType || type.contains('noteon')) {
          return NearbyQrPayload.decode(utf8.decode(record.payload));
        }
      }

      // Well-known Text (TNF=1, type='T')
      if (record.typeNameFormat == TypeNameFormat.wellKnown &&
          record.type.length == 1 &&
          record.type.first == 0x54 &&
          record.payload.isNotEmpty) {
        final langLen = record.payload.first & 0x3f;
        final text = utf8.decode(record.payload.sublist(1 + langLen));
        return NearbyQrPayload.decode(text);
      }

      // Absolute URI TNF
      if (record.typeNameFormat == TypeNameFormat.absoluteUri) {
        return NearbyQrPayload.decode(utf8.decode(record.payload));
      }

      // Last resort: raw UTF-8 JSON / URI string
      return NearbyQrPayload.decode(utf8.decode(record.payload));
    } on BackupException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Starts a session that writes [payload] to the next writable NDEF tag.
  static Future<void> startWriteSession({
    required NearbyQrPayload payload,
    required void Function() onSuccess,
    required void Function(String debug) onError,
  }) async {
    final message = messageFor(payload);
    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            if (!ndef.isWritable) {
              onError('not writable');
              await NfcManager.instance.stopSession();
              return;
            }
            if (ndef.maxSize < message.byteLength) {
              onError('tag too small');
              await NfcManager.instance.stopSession();
              return;
            }
            await ndef.write(message: message);
            await NfcManager.instance.stopSession();
            onSuccess();
            return;
          }

          final formatable = NdefFormatableAndroid.from(tag);
          if (formatable != null) {
            await formatable.format(message);
            await NfcManager.instance.stopSession();
            onSuccess();
            return;
          }

          onError('not ndef');
          await NfcManager.instance.stopSession();
        } catch (e) {
          onError('$e');
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
        }
      },
    );
  }

  /// Starts a session that reads a Noteon pairing record from the next tag.
  static Future<void> startReadSession({
    required void Function(NearbyQrPayload payload) onPayload,
    required void Function(String debug) onError,
  }) async {
    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            onError('not ndef');
            await NfcManager.instance.stopSession();
            return;
          }
          final message = ndef.cachedMessage ?? await ndef.read();
          final payload = payloadFromMessage(message);
          await NfcManager.instance.stopSession();
          if (payload == null) {
            onError('invalid payload');
            return;
          }
          onPayload(payload);
        } catch (e) {
          onError('$e');
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
        }
      },
    );
  }

  static Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}
