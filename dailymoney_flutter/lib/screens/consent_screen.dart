import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/capture_setup.dart';
import '../services/legal_content.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import 'legal_document_screen.dart';
import 'privacy_screen.dart';

/// Purpose-specific consent, with no preselected optional choices.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _working = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _setNotifications(bool value) async {
    if (_working) return;
    final settings = context.read<SettingsProvider>();
    if (!value) {
      await settings.setNotificationsConsent(false);
      _snack('Notifications turned off');
      return;
    }
    if (!NotificationService.isReady) {
      _snack('Notifications are unavailable on this device.');
      return;
    }
    setState(() => _working = true);
    final granted = await NotificationService.requestPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() => _working = false);
      _snack('Allow notifications in Android settings to use briefings.');
      return;
    }
    await settings.setNotificationsConsent(true);
    await settings.setMorningBriefing(true);
    await settings.setNightSummary(true);
    if (!mounted) return;
    setState(() => _working = false);
    _snack('Notifications enabled. You can choose each briefing in Settings.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Consent and permissions',
          style: TextStyle(color: scheme.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.toggleRight,
                  size: 24,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Only ask for what a feature needs',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Essential local storage keeps your ledger working. '
                        'Notifications and payment detection are optional and '
                        'start off.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'Essential processing'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.database, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Records and budget on this device',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            _pill(context, 'Always on', AppColors.income),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transactions, bills, goals, preferences and the '
                          'app-lock digest are stored locally so the features '
                          'you use can work. This processing is not used for '
                          'advertising, analytics or profiling.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'Optional choices'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.notificationsConsent,
                  onChanged: _working ? null : _setNotifications,
                  secondary: const Icon(LucideIcons.bell, size: 20),
                  title: const Text('Notifications'),
                  subtitle: Text(
                    settings.notificationsConsent
                        ? 'Allowed for morning, nightly and budget messages. '
                            'Choose each one in Settings.'
                        : 'Off. Used only for daily briefings, budget alerts '
                            'and detected-payment prompts.',
                  ),
                ),
                _divider(context),
                SwitchListTile(
                  value: settings.autoCapture,
                  onChanged: (v) => CaptureSetup.setEnabled(context, v),
                  secondary: const Icon(LucideIcons.radar, size: 20),
                  title: const Text('Payment detection'),
                  subtitle: Text(
                    settings.autoCapture
                        ? 'Notification access granted. Every detection waits '
                            'for your review.'
                        : 'Off. Reads payment-style notifications only after you '
                            'grant Android notification access.',
                  ),
                ),
                _divider(context),
                ListTile(
                  leading: const Icon(LucideIcons.lock, size: 20),
                  title: const Text('App lock and biometrics'),
                  subtitle: const Text(
                    'Optional. Configured in Settings > Security & privacy. '
                    'Android handles fingerprint or face matching.',
                  ),
                  trailing: Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: scheme.outline,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrivacyScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'What is not collected'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _notCollected(context, 'Analytics or behavioural tracking'),
                  _notCollected(context, 'Advertising or marketing profiles'),
                  _notCollected(
                      context, 'Contacts, SMS, call logs or location'),
                  _notCollected(context, 'Cloud sync or a DailyMoney account'),
                  _notCollected(context, 'Internet permission or bank linking'),
                  const SizedBox(height: 4),
                  Text(
                    'There is no analytics or marketing consent because those '
                    'data uses do not exist in this app.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'Recorded choices'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _recordRow(
                    context,
                    'Policy version',
                    settings.hasAcceptedCurrentPolicies
                        ? 'Accepted v$kLegalVersion'
                        : 'Not yet accepted',
                    settings.legalAcceptedAt,
                  ),
                  const SizedBox(height: 10),
                  _recordRow(
                    context,
                    'Notifications',
                    settings.notificationsConsent ? 'Allowed' : 'Off',
                    settings.notificationsConsentAt,
                  ),
                  const SizedBox(height: 10),
                  _recordRow(
                    context,
                    'Payment detection',
                    settings.autoCaptureConsent ? 'Allowed' : 'Off',
                    settings.autoCaptureConsentAt,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Times are stored on this device. Turning a choice off '
                    'stops the related processing; Android permission can also '
                    'be revoked in Android Settings. Full withdrawal of '
                    'essential processing is done by deleting all data.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.fileText, size: 20),
              title: const Text('Read the consent and permissions note'),
              subtitle: const Text('Versioned public explanation'),
              trailing: Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: scheme.outline,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LegalDocumentScreen(
                    document: consentAndPermissionsDocument,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notCollected(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.x, size: 14, color: AppColors.expense),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: scheme.onSurface.withValues(alpha: 0.80),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordRow(
    BuildContext context,
    String label,
    String value,
    String? at,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateTime.tryParse(at ?? '');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (date != null)
              Text(
                _dateLabel(date),
                style: TextStyle(fontSize: 10.5, color: scheme.outline),
              ),
          ],
        ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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

  Widget _divider(BuildContext context) => Divider(
        height: 1,
        indent: 56,
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
