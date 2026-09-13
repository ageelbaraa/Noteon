import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../domain/backup_models.dart';
import '../domain/nearby_transfer_models.dart';

/// Serves one encrypted `.noteonbak` over the local network for QR pairing.
class NearbyTransferServer {
  NearbyTransferServer({
    required this.archiveBytes,
    required this.token,
    required this.verifyCode,
  });

  final Uint8List archiveBytes;
  final String token;
  final String verifyCode;

  HttpServer? _server;
  final _downloads = StreamController<void>.broadcast();
  var _downloadCount = 0;

  Stream<void> get onDownloadStarted => _downloads.stream;
  int get downloadCount => _downloadCount;
  int? get port => _server?.port;
  bool get isRunning => _server != null;

  Future<int> start({int preferredPort = 0}) async {
    if (_server != null) {
      return _server!.port;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } on SocketException catch (e) {
      throw BackupException(BackupErrorCode.ioFailure, e.message);
    }

    unawaited(_serve());
    return _server!.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> dispose() async {
    await stop();
    await _downloads.close();
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;

    await for (final request in server) {
      try {
        await _handle(request);
      } catch (_) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Access-Control-Allow-Origin', '*');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    final path = request.uri.path;
    final requestToken = request.uri.queryParameters['token'];
    if (requestToken != token) {
      response.statusCode = HttpStatus.unauthorized;
      response.write('unauthorized');
      await response.close();
      return;
    }

    if (path == '/noteon/v1/meta' && request.method == 'GET') {
      response.headers.contentType = ContentType.json;
      response.write(
        '{"verify":"$verifyCode","bytes":${archiveBytes.length},"ready":true}',
      );
      await response.close();
      return;
    }

    if (path == '/noteon/v1/backup' && request.method == 'GET') {
      _downloadCount++;
      if (!_downloads.isClosed) {
        _downloads.add(null);
      }
      response.headers.contentType = ContentType('application', 'octet-stream');
      response.headers.contentLength = archiveBytes.length;
      response.headers.set(
        'Content-Disposition',
        'attachment; filename="noteon_backup.noteonbak"',
      );
      response.add(archiveBytes);
      await response.close();
      return;
    }

    response.statusCode = HttpStatus.notFound;
    await response.close();
  }
}

/// Downloads an encrypted backup from a nearby sender.
abstract final class NearbyTransferClient {
  static Future<Uint8List> download(
    NearbyQrPayload payload, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(payload.downloadUri);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw BackupException(
          BackupErrorCode.ioFailure,
          'status ${response.statusCode}',
        );
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(timeout)) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        throw const BackupException(BackupErrorCode.corruptPayload);
      }
      if (payload.byteLength > 0 && bytes.length != payload.byteLength) {
        throw const BackupException(
          BackupErrorCode.corruptPayload,
          'size mismatch',
        );
      }
      return bytes;
    } on TimeoutException {
      throw const BackupException(BackupErrorCode.ioFailure, 'timeout');
    } on SocketException catch (e) {
      throw BackupException(BackupErrorCode.ioFailure, e.message);
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException(BackupErrorCode.ioFailure, '$e');
    } finally {
      client.close(force: true);
    }
  }
}

/// Resolves a LAN IPv4 suitable for same-Wi‑Fi transfers.
abstract final class NearbyLocalAddress {
  static Future<String?> resolveIPv4() async {
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );

    String? fallback;
    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      if (name.contains('virtual') ||
          name.contains('vethernet') ||
          name.contains('docker') ||
          name.contains('vmware') ||
          name.contains('loopback')) {
        continue;
      }
      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        final ip = addr.address;
        if (_isPrivateLan(ip)) {
          if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
            return ip;
          }
          fallback ??= ip;
        }
      }
    }
    return fallback;
  }

  static bool _isPrivateLan(String ip) {
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length > 1) {
        final second = int.tryParse(parts[1]) ?? -1;
        if (second >= 16 && second <= 31) return true;
      }
    }
    return false;
  }
}
