import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:noteon/features/transfer/data/nearby_nfc_pairing.dart';
import 'package:noteon/features/transfer/data/nearby_transfer_transport.dart';
import 'package:noteon/features/transfer/domain/backup_models.dart';
import 'package:noteon/features/transfer/domain/nearby_transfer_models.dart';

void main() {
  test('NearbyQrPayload round-trips JSON', () {
    final payload = NearbyQrPayload(
      version: 1,
      host: '192.168.1.20',
      port: 41234,
      token: 'abcToken',
      verifyCode: 'AB12CD',
      byteLength: 2048,
    );
    final decoded = NearbyQrPayload.decode(payload.encode());
    expect(decoded.host, payload.host);
    expect(decoded.port, payload.port);
    expect(decoded.token, payload.token);
    expect(decoded.verifyCode, payload.verifyCode);
    expect(decoded.byteLength, payload.byteLength);
  });

  test('NearbyQrPayload round-trips compact URI', () {
    final payload = NearbyQrPayload(
      version: 1,
      host: '10.0.0.8',
      port: 9999,
      token: 'tok',
      verifyCode: 'ZZ99AA',
      byteLength: 10,
    );
    final decoded = NearbyQrPayload.decode(payload.encodeUri());
    expect(decoded.host, '10.0.0.8');
    expect(decoded.port, 9999);
    expect(decoded.verifyCode, 'ZZ99AA');
  });

  test('NearbyQrPayload rejects garbage', () {
    expect(
      () => NearbyQrPayload.decode('not-json'),
      throwsA(isA<BackupException>()),
    );
  });

  test('verify code and token generators produce expected shapes', () {
    final code = NearbyQrPayload.generateVerifyCode();
    expect(code, hasLength(6));
    expect(code, isNot(contains(RegExp(r'[01IO]'))));
    final token = NearbyQrPayload.generateToken();
    expect(token.length, greaterThan(10));
  });

  test('NFC NDEF message round-trips pairing payload', () {
    final payload = NearbyQrPayload(
      version: 1,
      host: '192.168.0.5',
      port: 8080,
      token: 'nfcToken',
      verifyCode: 'NFC123',
      byteLength: 42,
    );
    final message = NearbyNfcPairing.messageFor(payload);
    expect(message.records, hasLength(1));
    expect(message.records.first.typeNameFormat, TypeNameFormat.media);
    expect(
      utf8.decode(message.records.first.type),
      NearbyNfcPairing.mimeType,
    );
    final decoded = NearbyNfcPairing.payloadFromMessage(message);
    expect(decoded, isNotNull);
    expect(decoded!.host, payload.host);
    expect(decoded.token, payload.token);
    expect(decoded.verifyCode, payload.verifyCode);
  });

  test('NearbyTransferServer serves archive to authorized client', () async {
    final archive = Uint8List.fromList(utf8.encode('NOTEONBAK-test-bytes'));
    final token = NearbyQrPayload.generateToken();
    final verify = NearbyQrPayload.generateVerifyCode();
    final server = NearbyTransferServer(
      archiveBytes: archive,
      token: token,
      verifyCode: verify,
    );
    final port = await server.start(preferredPort: 0);
    addTearDown(server.dispose);

    final payload = NearbyQrPayload(
      version: 1,
      host: '127.0.0.1',
      port: port,
      token: token,
      verifyCode: verify,
      byteLength: archive.length,
    );

    final downloaded = await NearbyTransferClient.download(payload);
    expect(downloaded, archive);
    expect(server.downloadCount, 1);

    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final bad = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/noteon/v1/backup?token=wrong'),
    );
    final badResponse = await bad.close();
    expect(badResponse.statusCode, HttpStatus.unauthorized);
  });
}
