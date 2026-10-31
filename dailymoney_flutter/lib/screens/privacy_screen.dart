import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/goals_provider.dart';
import '../providers/security_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/backup_service.dart';
import '../theme.dart';
import 'consent_screen.dart';
import 'data_controls_screen.dart';
import 'legal_hub_screen.dart';

/// Plain-language permissions, encryption and data controls.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final security = context.watch<SecurityProvider>();
    final txs = context.watch<TransactionsProvider>();
    final goals = context.watch<GoalsProvider>();
    final upcoming = context.watch<UpcomingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Permissions & data',
          style: TextStyle(color: scheme.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.shieldCheck,
                  size: 26,
                  color: AppColors.income,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your data stays on this phone',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'No account, no cloud sync and no analytics. '
                        'Everything below is stored locally.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.outline,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _label(context, 'Storage'),
          Card(
            child: Column(
              children: [
                _row(
                  context,
                  icon: LucideIcons.lock,
                  title: 'Encrypted at rest',
                  subtitle: settings.encryptedAtRest
                      ? 'AES-256-GCM with a key held in the Android Keystore'
                      : 'Encryption unavailable — data is stored in app-private '
                          'storage',
                  trailing: _pill(
                    context,
                    settings.encryptedAtRest ? 'On' : 'Unavailable',
                    settings.encryptedAtRest
                        ? AppColors.income
                        : AppColors.warn,
                  ),
                ),
                _divider(context),
                _row(
                  context,
                  icon: LucideIcons.smartphone,
                  title: 'Local storage only',
                  subtitle:
                      '${txs.count} transactions · ${upcoming.count} bills · '
                      '${goals.count} goals',
                ),
                _divider(context),
                _row(
                  context,
                  icon: LucideIcons.lock,
                  title: 'App lock',
                  subtitle: security.pinEnabled
                      ? 'PIN enabled${security.biometricEnabled ? ' · biometrics on' : ''}'
                      : 'Not enabled',
                  trailing: _pill(
                    context,
                    security.pinEnabled ? 'On' : 'Off',
                    security.pinEnabled ? AppColors.income : scheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _label(context, 'Permissions'),
          Card(
            child: Column(
              children: [
                _row(
                  context,
                  icon: LucideIcons.bell,
                  title: 'Notifications',
                  subtitle:
                      'Optional. Used only for morning/night briefings, budget '
                      'alerts and detected-payment prompts.',
                  trailing: _pill(
                    context,
                    settings.notificationsConsent ? 'Allowed' : 'Off',
                    settings.notificationsConsent
                        ? AppColors.income
                        : scheme.outline,
                  ),
                ),
                _divider(context),
                _row(
                  context,
                  icon: LucideIcons.radar,
                  title: 'Notification access',
                  subtitle:
                      'Optional. Reads payment-like notifications from other '
                      'apps so you can review them. Nothing is added to your '
                      'ledger or sent off the phone.',
                  trailing: _pill(
                    context,
                    settings.autoCapture ? 'On' : 'Off',
                    settings.autoCapture ? AppColors.income : scheme.outline,
                  ),
                ),
                _divider(context),
                _row(
                  context,
                  icon: LucideIcons.wifiOff,
                  title: 'No internet, contacts or location',
                  subtitle:
                      'The app does not request these permissions, cannot see '
                      'your messages or calls, and never uploads your data.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _label(context, 'Your data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.download, size: 20),
                  title: const Text('Export a backup'),
                  subtitle: const Text(
                    'Copies a JSON file to the clipboard — keep it somewhere safe',
                  ),
                  onTap: () => copyBackupToClipboard(context),
                ),
                _divider(context),
                ListTile(
                  leading: const Icon(
                    LucideIcons.database,
                    size: 20,
                  ),
                  title: const Text('Review or erase all data'),
                  subtitle: const Text(
                    'See the full deletion scope, export first, or erase '
                    'everything on this device',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DataControlsScreen(),
                    ),
                  ),
                ),
                _divider(context),
                ListTile(
                  leading: const Icon(LucideIcons.shieldCheck, size: 20),
                  title: const Text('Legal & privacy'),
                  subtitle: const Text(
                    'Policies, acceptance, consent and support routes',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LegalHubScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.toggleRight, size: 20),
              title: const Text('Consent and permissions'),
              subtitle: const Text(
                'Review optional choices and when they were recorded',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConsentScreen()),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'DailyMoney has no servers. If you uninstall the app, the data is '
            'removed with it unless you exported a backup.',
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.outline,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: scheme.outline,
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.outline,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: trailing,
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Divider(
        height: 1,
        indent: 46,
        color:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      );

  Widget _pill(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
