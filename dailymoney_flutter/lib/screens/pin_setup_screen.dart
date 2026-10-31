import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../theme.dart';
import '../widgets/pin_pad.dart';

enum _Stage { current, fresh, confirm }

/// Create or change the app-lock PIN.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, this.requireCurrent = false});

  /// When true the user must verify the existing PIN first.
  final bool requireCurrent;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  late _Stage _stage;
  String _pin = '';
  String _first = '';
  String? _error;
  bool _busy = false;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _stage = widget.requireCurrent ? _Stage.current : _Stage.fresh;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final security = context.read<SecurityProvider>();
      if (security.pinLockedOut) _startLockTimer();
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final security = context.read<SecurityProvider>();
      setState(() {});
      if (!security.pinLockedOut) {
        _lockTimer?.cancel();
        _lockTimer = null;
      }
    });
  }

  bool get _lockedOut {
    if (_stage != _Stage.current) return false;
    return context.read<SecurityProvider>().pinLockedOut;
  }

  void _onDigit(int digit) {
    if (_busy || _lockedOut || _pin.length >= SecurityProvider.pinLength) {
      return;
    }
    setState(() {
      _error = null;
      _pin += '$digit';
    });
    if (_pin.length == SecurityProvider.pinLength) _advance();
  }

  void _onBackspace() {
    if (_busy || _lockedOut || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _advance() async {
    final security = context.read<SecurityProvider>();
    if (_stage == _Stage.current && security.pinLockedOut) {
      setState(() {
        _pin = '';
        _error = _lockoutMessage(security);
      });
      return;
    }
    final entered = _pin;
    setState(() => _busy = true);

    switch (_stage) {
      case _Stage.current:
        final ok = await security.verifyPin(entered);
        if (!mounted) return;
        if (!ok) {
          HapticFeedback.mediumImpact();
          setState(() {
            _busy = false;
            _pin = '';
            _error = security.pinLockedOut
                ? _lockoutMessage(security)
                : 'That PIN is not correct';
          });
          if (security.pinLockedOut) _startLockTimer();
          return;
        }
        setState(() {
          _busy = false;
          _pin = '';
          _stage = _Stage.fresh;
        });

      case _Stage.fresh:
        setState(() {
          _busy = false;
          _first = entered;
          _pin = '';
          _stage = _Stage.confirm;
        });

      case _Stage.confirm:
        if (entered != _first) {
          HapticFeedback.mediumImpact();
          setState(() {
            _busy = false;
            _pin = '';
            _error = 'PINs do not match. Try again.';
          });
          return;
        }
        await security.setPin(entered);
        if (!mounted) return;
        Navigator.pop(context, true);
    }
  }

  String _lockoutMessage(SecurityProvider security) {
    final seconds = security.pinLockoutRemaining.inSeconds;
    final wait = seconds < 60
        ? '${seconds}s'
        : '${seconds ~/ 60}m ${(seconds % 60).toString().padLeft(2, '0')}s';
    return 'Too many attempts. Try again in $wait.';
  }

  String get _title => switch (_stage) {
        _Stage.current => 'Enter your current PIN',
        _Stage.fresh => 'Choose a PIN',
        _Stage.confirm => 'Confirm your PIN',
      };

  String get _subtitle => switch (_stage) {
        _Stage.current => 'Confirm it is you before changing the lock.',
        _Stage.fresh => 'Four digits. It unlocks the app on this device only.',
        _Stage.confirm => 'Type the same four digits once more.',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final security = context.watch<SecurityProvider>();
    final lockedOut = _stage == _Stage.current && security.pinLockedOut;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.requireCurrent ? 'Change PIN' : 'Set app lock',
          style: TextStyle(color: scheme.onSurface),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        LucideIcons.lock,
                        size: 26,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.outline,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    PinDots(
                      length: SecurityProvider.pinLength,
                      filled: _pin.length,
                      error: _error != null,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: Center(
                        child: Text(
                          _error ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.error,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    PinKeypad(
                      enabled: !_busy && !lockedOut,
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.shieldCheck,
                          size: 14,
                          color: AppColors.income,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Stored as a PBKDF2 hash, protected by the Android '
                            'Keystore',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
