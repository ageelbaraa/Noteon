import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_localizations.dart';

/// Numeric keypad with dots for the digits entered.
///
/// [onComplete] runs once [length] digits are entered. Returning a message
/// shows it, shakes the dots, vibrates and clears the entry; returning null
/// means the entry was accepted. While [lockoutRemaining] returns a duration,
/// input is paused and a countdown is shown.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.length,
    required this.onComplete,
    this.lockoutRemaining,
  });

  final String title;
  final int length;
  final Future<String?> Function(String pin) onComplete;
  final Duration? Function()? lockoutRemaining;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  Timer? _ticker;
  String _entry = '';
  String? _error;
  bool _busy = false;
  Duration? _lockout;

  @override
  void initState() {
    super.initState();
    _syncLockout();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _syncLockout());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    super.dispose();
  }

  void _syncLockout() {
    final remaining = widget.lockoutRemaining?.call();
    if (remaining != _lockout && mounted) {
      setState(() {
        _lockout = remaining;
        if (remaining != null) {
          _entry = '';
        } else {
          _error = null;
        }
      });
    }
  }

  Future<void> _digit(String digit) async {
    if (_busy || _lockout != null || _entry.length >= widget.length) {
      return;
    }
    setState(() {
      _entry += digit;
      _error = null;
    });
    if (_entry.length < widget.length) {
      return;
    }
    _busy = true;
    final error = await widget.onComplete(_entry);
    _busy = false;
    if (!mounted) {
      return;
    }
    if (error != null) {
      HapticFeedback.vibrate();
      _shake.forward(from: 0);
    }
    setState(() {
      _entry = '';
      _error = error;
    });
    _syncLockout();
  }

  void _backspace() {
    if (_busy || _entry.isEmpty) {
      return;
    }
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lockout = _lockout;
    final message = lockout != null
        ? l10n.appLockTryAgainIn((lockout.inMilliseconds / 1000).ceil())
        : _error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(math.sin(_shake.value * math.pi * 6) * 10 *
                (1 - _shake.value), 0),
            child: child,
          ),
          child: Semantics(
            label: l10n.appLockPinProgress(_entry.length, widget.length),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.length; i++)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _entry.length
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: _error != null || lockout != null
                            ? theme.colorScheme.error
                            : theme.colorScheme.outline,
                        width: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: Center(
            child: message == null
                ? null
                : Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
          ),
        ),
        // Digits keep the familiar layout in RTL languages too.
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 264,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                  _Key(label: d, onTap: () => _digit(d)),
                const SizedBox(width: 72, height: 72),
                _Key(label: '0', onTap: () => _digit('0')),
                _Key(
                  icon: Icons.backspace_outlined,
                  semanticLabel: l10n.appLockBackspace,
                  onTap: _backspace,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.semanticLabel, required this.onTap});

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: label != null
                  ? Text(label!, style: theme.textTheme.headlineSmall)
                  : Icon(icon),
            ),
          ),
        ),
      ),
    );
  }
}
