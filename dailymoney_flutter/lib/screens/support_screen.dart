import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/capture_provider.dart';
import '../providers/goals_provider.dart';
import '../providers/security_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/legal_content.dart';
import '../theme.dart';

/// Support, bug reporting, privacy complaints and security reporting.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _details = TextEditingController();
  String _topic = 'Bug report';
  bool _includeTechnical = true;

  static const _topics = [
    'Bug report',
    'Incorrect calculation',
    'Privacy complaint',
    'Security issue',
    'Accessibility issue',
    'Other',
  ];

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copyEmail(String email) async {
    if (email.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: email));
    _snack('Email address copied: $email');
  }

  Future<void> _copyReport() async {
    if (_details.text.trim().isEmpty) {
      _snack('Describe the issue first so the report is useful.');
      return;
    }
    final settings = context.read<SettingsProvider>();
    final security = context.read<SecurityProvider>();
    final txs = context.read<TransactionsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final goals = context.read<GoalsProvider>();
    final capture = context.read<CaptureProvider>();

    final buffer = StringBuffer()
      ..writeln('DailyMoney support report')
      ..writeln('Topic: $_topic')
      ..writeln()
      ..writeln('Issue:')
      ..writeln(_details.text.trim())
      ..writeln();

    if (_includeTechnical) {
      buffer
        ..writeln('--- Technical details ---')
        ..writeln('App version: $kAppVersion')
        ..writeln('Platform: ${defaultTargetPlatform.name}')
        ..writeln('Policies: $kLegalVersion')
        ..writeln('Consent version: $kConsentVersion')
        ..writeln('Encryption at rest: ${settings.encryptedAtRest}')
        ..writeln('App lock: ${security.pinEnabled}')
        ..writeln('Notifications consent: ${settings.notificationsConsent}')
        ..writeln('Payment detection: ${settings.autoCapture}')
        ..writeln('Transaction count: ${txs.count}')
        ..writeln('Upcoming bill count: ${upcoming.count}')
        ..writeln('Savings goal count: ${goals.count}')
        ..writeln('Detected payment count: ${capture.count}')
        ..writeln('Tutorial completed: ${settings.tutorialCompleted}')
        ..writeln()
        ..writeln(
          'No transaction amounts, notes, names, account numbers or '
          'notification text are included in these technical details.',
        );
    }

    buffer
      ..writeln()
      ..writeln(
        'Do not include one-time passwords, full account numbers, card '
        'numbers or bank credentials in a support message.',
      );

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    _snack('Report copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final general = supportEmailFor('general');
    final privacy = supportEmailFor('privacy');
    final security = supportEmailFor('security');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Support & complaints',
          style: TextStyle(color: scheme.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
        children: [
          if (!hasConfiguredSupportContact)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.alertTriangle,
                    size: 19,
                    color: AppColors.warn,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support contact not configured in this build',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'The app will not invent an address. You can still '
                          'copy a report and send it through the channel that '
                          'provided this beta build. A monitored support '
                          'address is required before public release.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.lifeBuoy,
                    size: 20,
                    color: AppColors.income,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      kSupportResponseTime.isEmpty
                          ? 'A support contact is configured. No response-time '
                              'target is published for this beta build.'
                          : 'A support contact is configured. Target response: '
                              '$kSupportResponseTime.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _label(context, 'Contact routes'),
          Card(
            child: Column(
              children: [
                _contactTile(
                  context,
                  icon: LucideIcons.lifeBuoy,
                  title: 'General support',
                  subtitle: 'Bugs, incorrect calculations and accessibility',
                  email: general,
                  onCopy: _copyEmail,
                ),
                _divider(context),
                _contactTile(
                  context,
                  icon: LucideIcons.lock,
                  title: 'Privacy complaint',
                  subtitle: 'Data access, retention, consent or deletion',
                  email: privacy,
                  onCopy: _copyEmail,
                ),
                _divider(context),
                _contactTile(
                  context,
                  icon: LucideIcons.shieldAlert,
                  title: 'Security issue',
                  subtitle:
                      'Suspected exposure, bypass or unsafe behaviour. Do not '
                      'send OTPs, PINs or full account numbers.',
                  email: security,
                  onCopy: _copyEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'Build a report'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What kind of issue is it?',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _topic,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(14),
                        items: [
                          for (final topic in _topics)
                            DropdownMenuItem(
                              value: topic,
                              child: Text(
                                topic,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _topic = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _details,
                    minLines: 4,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText:
                          'What did you expect, what happened, and which screen '
                          'were you on? For a calculation, include the numbers '
                          'you expected and saw.',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _includeTechnical,
                    onChanged: (v) =>
                        setState(() => _includeTechnical = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Include technical details',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    subtitle: const Text(
                      'Version, platform, encryption state and record counts. '
                      'No amounts, notes or names.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _copyReport,
                      icon: const Icon(LucideIcons.copy, size: 16),
                      label: const Text('Copy report'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    general.isNotEmpty
                        ? 'Send the copied text to $general.'
                        : 'Send the copied text through the channel that '
                            'provided this beta build.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'Before you send'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullets(
                    context,
                    'For an incorrect calculation, say which screen and which '
                    'number looks wrong. Never send a bank password, PIN or OTP.',
                  ),
                  _bullets(
                    context,
                    'For a privacy request, say what you want to access, correct '
                    'or delete. Because the app has no account, deletion is '
                    'performed on your device in Data controls.',
                  ),
                  _bullets(
                    context,
                    'For a security issue, give enough detail to reproduce it '
                    'without exposing another person\'s data.',
                  ),
                  _bullets(
                    context,
                    'No response-time target is promised unless one is shown at '
                    'the top of this screen.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'DailyMoney has no server and cannot recover a backup for you. '
            'Keep your exported JSON somewhere safe.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: scheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String email,
    required ValueChanged<String> onCopy,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
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
                    height: 1.45,
                    color: scheme.outline,
                  ),
                ),
                const SizedBox(height: 6),
                if (email.isEmpty)
                  const Text(
                    'Not configured in this build',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warn,
                    ),
                  )
                else
                  Row(
                    children: [
                      Flexible(
                        child: SelectableText(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Copy email address',
                        onPressed: () => onCopy(email),
                        icon: const Icon(LucideIcons.copy, size: 15),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullets(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(LucideIcons.check, size: 13, color: AppColors.brand),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: scheme.onSurface.withValues(alpha: 0.80),
              ),
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

  Widget _divider(BuildContext context) => Divider(
        height: 1,
        indent: 48,
        color:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      );
}
