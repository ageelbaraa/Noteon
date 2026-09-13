import 'dart:convert';
import 'dart:math';

import 'backup_models.dart';

/// QR / session metadata for a same-Wi‑Fi nearby backup transfer.
class NearbyQrPayload {
  const NearbyQrPayload({
    required this.version,
    required this.host,
    required this.port,
    required this.token,
    required this.verifyCode,
    required this.byteLength,
  });

  static const currentVersion = 1;
  static const schemePrefix = 'noteon://transfer?';

  final int version;
  final String host;
  final int port;
  final String token;

  /// Short mutual confirmation code shown on both devices.
  final String verifyCode;
  final int byteLength;

  Uri get downloadUri => Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: '/noteon/v1/backup',
        queryParameters: {'token': token},
      );

  Uri get metaUri => Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: '/noteon/v1/meta',
        queryParameters: {'token': token},
      );

  Map<String, Object?> toJson() => {
        'v': version,
        'host': host,
        'port': port,
        'token': token,
        'verify': verifyCode,
        'bytes': byteLength,
      };

  String encode() => jsonEncode(toJson());

  /// Compact URI form for NFC / deep-link style pairing.
  String encodeUri() {
    return Uri(
      scheme: 'noteon',
      host: 'transfer',
      queryParameters: {
        'v': '$version',
        'host': host,
        'port': '$port',
        'token': token,
        'verify': verifyCode,
        'bytes': '$byteLength',
      },
    ).toString();
  }

  factory NearbyQrPayload.decode(String raw) {
    final trimmed = raw.trim();
    late final Object? decoded;
    try {
      if (trimmed.startsWith(schemePrefix)) {
        final uri = Uri.parse(trimmed);
        decoded = {
          'v': int.tryParse(uri.queryParameters['v'] ?? '') ?? currentVersion,
          'host': uri.queryParameters['host'],
          'port': int.tryParse(uri.queryParameters['port'] ?? ''),
          'token': uri.queryParameters['token'],
          'verify': uri.queryParameters['verify'],
          'bytes': int.tryParse(uri.queryParameters['bytes'] ?? ''),
        };
      } else {
        decoded = jsonDecode(trimmed);
      }
    } catch (_) {
      throw const BackupException(BackupErrorCode.invalidFormat, 'nearby qr');
    }

    if (decoded is! Map) {
      throw const BackupException(BackupErrorCode.invalidFormat, 'nearby qr');
    }
    final map = decoded.cast<String, Object?>();
    final host = map['host'] as String?;
    final port = map['port'];
    final token = map['token'] as String?;
    final verify = map['verify'] as String?;
    final bytes = map['bytes'];
    final version = map['v'] as int? ?? currentVersion;

    if (host == null ||
        host.isEmpty ||
        port is! int ||
        token == null ||
        token.isEmpty ||
        verify == null ||
        verify.isEmpty ||
        bytes is! int ||
        bytes <= 0 ||
        version != currentVersion) {
      throw const BackupException(BackupErrorCode.invalidFormat, 'nearby qr');
    }

    return NearbyQrPayload(
      version: version,
      host: host,
      port: port,
      token: token,
      verifyCode: verify,
      byteLength: bytes,
    );
  }

  /// 6-character code from unambiguous alphabet (no 0/O/1/I).
  static String generateVerifyCode([Random? random]) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = random ?? Random.secure();
    return List.generate(6, (_) => alphabet[rng.nextInt(alphabet.length)])
        .join();
  }

  static String generateToken([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

enum NearbySenderPhase {
  preparing,
  advertising,
  transferring,
  completed,
  failed,
}

enum NearbyReceiverPhase {
  scanning,
  confirming,
  downloading,
  readyToImport,
  failed,
}
