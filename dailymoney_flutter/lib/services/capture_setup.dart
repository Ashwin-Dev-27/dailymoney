import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'capture_service.dart';

/// Enables or disables payment detection with the same explanation everywhere.
///
/// Notification access is a separate Android permission from notification
/// delivery. It is requested only when the user turns payment detection on,
/// and the feature is only marked enabled once access is actually granted.
class CaptureSetup {
  const CaptureSetup._();

  static Future<void> setEnabled(BuildContext context, bool value) async {
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (!value) {
      await settings.setAutoCapture(false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Payment detection off')),
      );
      return;
    }

    final granted = await CaptureService.hasAccess();
    if (!context.mounted) return;
    if (granted) {
      await settings.setAutoCapture(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Payment detection on - detected payments wait for your review',
          ),
        ),
      );
      return;
    }

    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Allow notification access?'),
        content: const Text(
          'Android must let DailyMoney read notifications before payment '
          'messages can be detected. Nothing is added to your ledger until you '
          'confirm it. DailyMoney keeps only payment-like notifications with an '
          'amount; the rest are ignored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (open == true) {
      await CaptureService.openSettings();
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'After granting access, turn on payment detection again.',
          ),
        ),
      );
    }
  }
}
