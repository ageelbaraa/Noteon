import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/noteon_background.dart';
import '../data/nearby_nfc_pairing.dart';
import '../data/nearby_transfer_transport.dart';
import '../domain/backup_models.dart';
import '../domain/nearby_transfer_models.dart';

enum _ReceiveMethod { qr, nfc }

/// Receiver: scan sender QR or NFC tag, confirm code, download archive.
class NearbyReceiveScreen extends StatefulWidget {
  const NearbyReceiveScreen({super.key});

  @override
  State<NearbyReceiveScreen> createState() => _NearbyReceiveScreenState();
}

class _NearbyReceiveScreenState extends State<NearbyReceiveScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  NearbyReceiverPhase _phase = NearbyReceiverPhase.scanning;
  NearbyQrPayload? _payload;
  String? _error;
  var _handledScan = false;
  var _nfcAvailable = false;
  var _nfcListening = false;
  _ReceiveMethod _method = _ReceiveMethod.qr;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNfcAvailability());
  }

  @override
  void dispose() {
    unawaited(NearbyNfcPairing.stopSession());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadNfcAvailability() async {
    final available = await NearbyNfcPairing.isAssistAvailable();
    if (!mounted) return;
    setState(() => _nfcAvailable = available);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handledScan ||
        _phase != NearbyReceiverPhase.scanning ||
        _method != _ReceiveMethod.qr) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      try {
        final payload = NearbyQrPayload.decode(raw);
        _acceptPayload(payload);
        return;
      } on BackupException {
        // Keep scanning until a valid Noteon QR is found.
      } catch (_) {}
    }
  }

  Future<void> _acceptPayload(NearbyQrPayload payload) async {
    if (_handledScan) return;
    _handledScan = true;
    if (_method == _ReceiveMethod.qr) {
      unawaited(_controller.stop());
    }
    if (_nfcListening) {
      await NearbyNfcPairing.stopSession();
      _nfcListening = false;
    }
    if (!mounted) return;
    setState(() {
      _payload = payload;
      _phase = NearbyReceiverPhase.confirming;
    });
  }

  Future<void> _setMethod(_ReceiveMethod method) async {
    if (method == _method) return;
    if (method == _ReceiveMethod.nfc) {
      await _controller.stop();
      setState(() => _method = method);
      await _startNfcRead();
    } else {
      await NearbyNfcPairing.stopSession();
      _nfcListening = false;
      setState(() => _method = method);
      await _controller.start();
    }
  }

  Future<void> _startNfcRead() async {
    final l10n = AppLocalizations.of(context);
    if (_nfcListening) return;
    setState(() {
      _nfcListening = true;
      _error = null;
    });
    try {
      await NearbyNfcPairing.startReadSession(
        onPayload: (payload) {
          unawaited(_acceptPayload(payload));
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _nfcListening = false;
            _error = l10n.nearbyNfcReadFailed;
          });
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nfcListening = false;
        _error = l10n.nearbyNfcReadFailed;
      });
    }
  }

  Future<void> _confirmAndDownload() async {
    final payload = _payload;
    if (payload == null) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _phase = NearbyReceiverPhase.downloading;
      _error = null;
    });

    try {
      final bytes = await NearbyTransferClient.download(payload);
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(bytes);
    } on BackupException {
      if (!mounted) return;
      setState(() {
        _phase = NearbyReceiverPhase.failed;
        _error = l10n.nearbyReceiveFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = NearbyReceiverPhase.failed;
        _error = l10n.nearbyReceiveFailed;
      });
    }
  }

  Future<void> _rescan() async {
    _handledScan = false;
    _payload = null;
    await NearbyNfcPairing.stopSession();
    _nfcListening = false;
    setState(() {
      _phase = NearbyReceiverPhase.scanning;
      _error = null;
    });
    if (_method == _ReceiveMethod.nfc) {
      await _startNfcRead();
    } else {
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final payload = _payload;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.nearbyReceiveTitle)),
      body: NoteonBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: switch (_phase) {
              NearbyReceiverPhase.scanning => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_nfcAvailable) ...[
                      SegmentedButton<_ReceiveMethod>(
                        segments: [
                          ButtonSegment(
                            value: _ReceiveMethod.qr,
                            label: Text(l10n.nearbyMethodQr),
                            icon: const Icon(Icons.qr_code_scanner),
                          ),
                          ButtonSegment(
                            value: _ReceiveMethod.nfc,
                            label: Text(l10n.nearbyMethodNfc),
                            icon: const Icon(Icons.nfc),
                          ),
                        ],
                        selected: {_method},
                        onSelectionChanged: (value) {
                          unawaited(_setMethod(value.first));
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _method == _ReceiveMethod.nfc
                          ? l10n.nearbyReceiveNfcMessage
                          : l10n.nearbyReceiveScanMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Expanded(
                      child: _method == _ReceiveMethod.nfc
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.nfc,
                                    size: 72,
                                    color: AppColors.teal,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _nfcListening
                                        ? l10n.nearbyNfcListening
                                        : l10n.nearbyNfcReadFailed,
                                    textAlign: TextAlign.center,
                                  ),
                                  if (!_nfcListening) ...[
                                    const SizedBox(height: 16),
                                    FilledButton(
                                      onPressed: _startNfcRead,
                                      child: Text(l10n.nearbyNfcRetry),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: MobileScanner(
                                controller: _controller,
                                onDetect: _onDetect,
                              ),
                            ),
                    ),
                  ],
                ),
              NearbyReceiverPhase.confirming => ListView(
                  children: [
                    Text(
                      l10n.nearbyConfirmMessage,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.nearbyVerifyCodeLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      payload?.verifyCode ?? '',
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
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _confirmAndDownload,
                      child: Text(l10n.nearbyCodesMatch),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _rescan,
                      child: Text(l10n.nearbyRescan),
                    ),
                  ],
                ),
              NearbyReceiverPhase.downloading => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.nearbyDownloading),
                    ],
                  ),
                ),
              NearbyReceiverPhase.failed => Center(
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
                        _error ?? l10n.nearbyReceiveFailed,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _rescan,
                        child: Text(l10n.nearbyRescan),
                      ),
                    ],
                  ),
                ),
              NearbyReceiverPhase.readyToImport => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }
}
