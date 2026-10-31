import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../providers/settings_provider.dart';
import '../services/data_reset.dart';
import '../theme.dart';
import '../widgets/pin_pad.dart';

/// Full-screen lock shown before the app when a PIN is enabled.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _error = false;
  bool _checking = false;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final security = context.read<SecurityProvider>();
      if (security.pinLockedOut) _startLockTimer();
      if (security.biometricEnabled) _biometric();
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  /// Rebuilds once a second while a cooldown is running, then stops itself.
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

  void _onDigit(int digit) {
    final security = context.read<SecurityProvider>();
    if (_checking ||
        security.pinLockedOut ||
        _pin.length >= SecurityProvider.pinLength) {
      return;
    }
    setState(() {
      _error = false;
      _pin += '$digit';
    });
    if (_pin.length == SecurityProvider.pinLength) _submit();
  }

  void _onBackspace() {
    final security = context.read<SecurityProvider>();
    if (_checking || security.pinLockedOut || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final security = context.read<SecurityProvider>();
    if (security.pinLockedOut) return;
    setState(() => _checking = true);
    final ok = await security.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      security.unlock();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _checking = false;
      _error = true;
      _pin = '';
    });
    if (security.pinLockedOut) _startLockTimer();
  }

  Future<void> _biometric() async {
    final security = context.read<SecurityProvider>();
    if (_checking) return;
    final ok = await security.authenticateBiometric();
    if (!mounted || ok) return;
    setState(() => _error = true);
  }

  String _statusText(SecurityProvider security) {
    if (security.pinLockedOut) {
      return 'Too many attempts. Try again in '
          '${_formatRemaining(security.pinLockoutRemaining)}.';
    }
    if (!_error) return '';
    final left = SecurityProvider.maxPinAttempts - security.failedPinAttempts;
    if (left > 0 && left <= 2) {
      return 'Wrong PIN. $left ${left == 1 ? 'attempt' : 'attempts'} left.';
    }
    return 'Wrong PIN. Try again.';
  }

  String _formatRemaining(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes}m ${rest.toString().padLeft(2, '0')}s';
  }

  Future<void> _forgotPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content: const Text(
          'The PIN protects data stored only on this phone, so it cannot be '
          'recovered. Resetting erases every transaction, bill, goal and '
          'setting. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase & reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await wipeAllData(context);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App data erased')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final security = context.watch<SecurityProvider>();
    final name = settings.userName.trim();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        LucideIcons.wallet,
                        size: 30,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'DailyMoney',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name.isEmpty
                          ? 'Enter your PIN to continue'
                          : 'Welcome back, $name',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: scheme.outline),
                    ),
                    const SizedBox(height: 28),
                    PinDots(
                      length: SecurityProvider.pinLength,
                      filled: _pin.length,
                      error: _error,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: Center(
                        child: Text(
                          _statusText(security),
                          textAlign: TextAlign.center,
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
                      enabled: !_checking && !security.pinLockedOut,
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      trailing: security.biometricEnabled
                          ? IconButton(
                              tooltip: 'Unlock with biometrics',
                              onPressed: _biometric,
                              icon: Icon(
                                LucideIcons.fingerprint,
                                size: 26,
                                color: scheme.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: _forgotPin,
                      child: const Text('Forgot PIN?'),
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
