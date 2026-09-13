import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/noteon_background.dart';
import '../data/nearby_nfc_pairing.dart';
import '../data/nearby_transfer_transport.dart';
import '../domain/backup_models.dart';
import '../domain/nearby_transfer_models.dart';
import 'transfer_providers.dart';

/// Sender: encrypt backup, host LAN server, show QR + optional NFC tag write.
class NearbySendScreen extends ConsumerStatefulWidget {
  const NearbySendScreen({super.key, required this.passphrase});

  final String passphrase;

  @override
  ConsumerState<NearbySendScreen> createState() => _NearbySendScreenState();
}

class _NearbySendScreenState extends ConsumerState<NearbySendScreen> {
  NearbySenderPhase _phase = NearbySenderPhase.preparing;
  String? _error;
  NearbyQrPayload? _payload;
  NearbyTransferServer? _server;
  StreamSubscription<void>? _downloadSub;
  var _nfcAvailable = false;
  var _nfcListening = false;
  var _nfcWritten = false;
  String? _nfcStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    unawaited(_teardown());
    super.dispose();
  }

  Future<void> _teardown() async {
    await _downloadSub?.cancel();
    _downloadSub = null;
    if (_nfcListening) {
      await NearbyNfcPairing.stopSession();
      _nfcListening = false;
    }
    final server = _server;
    _server = null;
    await server?.dispose();
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await ref
          .read(backupServiceProvider)
          .exportEncryptedBackup(passphrase: widget.passphrase);

      final host = await NearbyLocalAddress.resolveIPv4();
      if (host == null) {
        if (!mounted) return;
        setState(() {
          _phase = NearbySenderPhase.failed;
          _error = l10n.nearbyNoWifiAddress;
        });
        return;
      }

      final token = NearbyQrPayload.generateToken();
      final verify = NearbyQrPayload.generateVerifyCode();
      final server = NearbyTransferServer(
        archiveBytes: bytes,
        token: token,
        verifyCode: verify,
      );
      final port = await server.start(preferredPort: 0);
      final payload = NearbyQrPayload(
        version: NearbyQrPayload.currentVersion,
        host: host,
        port: port,
        token: token,
        verifyCode: verify,
        byteLength: bytes.length,
      );

      _server = server;
      _downloadSub = server.onDownloadStarted.listen((_) {
        if (!mounted) return;
        setState(() => _phase = NearbySenderPhase.completed);
      });

      final nfc = await NearbyNfcPairing.isAssistAvailable();

      if (!mounted) {
        await server.dispose();
        return;
      }
      setState(() {
        _payload = payload;
        _phase = NearbySenderPhase.advertising;
        _nfcAvailable = nfc;
      });
    } on BackupException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = NearbySenderPhase.failed;
        _error = e.code == BackupErrorCode.passphraseTooShort
            ? l10n.passwordTooShort
            : l10n.nearbySendFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = NearbySenderPhase.failed;
        _error = l10n.nearbySendFailed;
      });
    }
  }

  Future<void> _startNfcWrite() async {
    final payload = _payload;
    if (payload == null || _nfcListening) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _nfcListening = true;
      _nfcWritten = false;
      _nfcStatus = l10n.nearbyNfcWriteHint;
    });
    try {
      await NearbyNfcPairing.startWriteSession(
        payload: payload,
        onSuccess: () {
          if (!mounted) return;
          setState(() {
            _nfcListening = false;
            _nfcWritten = true;
            _nfcStatus = l10n.nearbyNfcWriteSuccess;
          });
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _nfcListening = false;
            _nfcStatus = l10n.nearbyNfcWriteFailed;
          });
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nfcListening = false;
        _nfcStatus = l10n.nearbyNfcWriteFailed;
      });
    }
  }

  Future<void> _stopNfcWrite() async {
    await NearbyNfcPairing.stopSession();
    if (!mounted) return;
    setState(() {
      _nfcListening = false;
      if (!_nfcWritten) {
        _nfcStatus = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final payload = _payload;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.nearbySendTitle)),
      body: NoteonBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: switch (_phase) {
              NearbySenderPhase.preparing => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.nearbyPreparing),
                    ],
                  ),
                ),
              NearbySenderPhase.failed => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error ?? l10n.nearbySendFailed,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                    ],
                  ),
                ),
              NearbySenderPhase.advertising ||
              NearbySenderPhase.transferring ||
              NearbySenderPhase.completed =>
                payload == null
                    ? const SizedBox.shrink()
                    : _AdvertisingBody(
                        payload: payload,
                        phase: _phase,
                        nfcAvailable: _nfcAvailable,
                        nfcListening: _nfcListening,
                        nfcWritten: _nfcWritten,
                        nfcStatus: _nfcStatus,
                        onStartNfc: _startNfcWrite,
                        onStopNfc: _stopNfcWrite,
                        onDone: () {
                          setState(() => _phase = NearbySenderPhase.completed);
                        },
                      ),
            },
          ),
        ),
      ),
    );
  }
}

class _AdvertisingBody extends StatelessWidget {
  const _AdvertisingBody({
    required this.payload,
    required this.phase,
    required this.nfcAvailable,
    required this.nfcListening,
    required this.nfcWritten,
    required this.nfcStatus,
    required this.onStartNfc,
    required this.onStopNfc,
    required this.onDone,
  });

  final NearbyQrPayload payload;
  final NearbySenderPhase phase;
  final bool nfcAvailable;
  final bool nfcListening;
  final bool nfcWritten;
  final String? nfcStatus;
  final VoidCallback onStartNfc;
  final VoidCallback onStopNfc;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = switch (phase) {
      NearbySenderPhase.transferring => l10n.nearbyTransferring,
      NearbySenderPhase.completed => l10n.nearbySendComplete,
      _ => l10n.nearbyWaitingReceiver,
    };

    return ListView(
      children: [
        Text(
          l10n.nearbySendMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: payload.encode(),
              size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F172A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.nearbyVerifyCodeLabel,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(
          payload.verifyCode,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.nearbyVerifyHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (nfcAvailable && phase != NearbySenderPhase.completed) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: nfcListening ? onStopNfc : onStartNfc,
            icon: Icon(
              nfcListening ? Icons.nfc : Icons.nfc_outlined,
            ),
            label: Text(
              nfcListening ? l10n.nearbyNfcCancel : l10n.nearbyNfcWriteAction,
            ),
          ),
          if (nfcStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              nfcStatus!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: nfcWritten
                    ? AppColors.teal
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),
        Text(
          status,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (phase == NearbySenderPhase.transferring) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onDone,
            child: Text(l10n.nearbyMarkComplete),
          ),
        ],
        if (phase == NearbySenderPhase.completed) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.nearbyDone),
          ),
        ],
      ],
    );
  }
}
