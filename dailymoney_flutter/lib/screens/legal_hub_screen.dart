import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/legal_content.dart';
import '../theme.dart';
import 'consent_screen.dart';
import 'data_controls_screen.dart';
import 'legal_document_screen.dart';
import 'privacy_screen.dart';
import 'support_screen.dart';

/// One accessible place for policies, consent, support and data controls.
class LegalHubScreen extends StatefulWidget {
  const LegalHubScreen({super.key});

  @override
  State<LegalHubScreen> createState() => _LegalHubScreenState();
}

class _LegalHubScreenState extends State<LegalHubScreen> {
  bool _privacyRead = false;
  bool _termsRead = false;

  void _open(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Legal & privacy', style: TextStyle(color: scheme.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        'Clear rules, local data',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'No account, no cloud sync, no analytics and no '
                        'internet permission. These documents describe the '
                        'build installed on this device.',
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
          _sectionLabel(context, 'Policies'),
          Card(
            child: Column(
              children: [
                _docTile(
                  context,
                  icon: LucideIcons.lock,
                  title: privacyPolicy.title,
                  subtitle: 'What is stored, why, and how to delete it',
                  document: privacyPolicy,
                ),
                _divider(context),
                _docTile(
                  context,
                  icon: LucideIcons.fileText,
                  title: termsOfService.title,
                  subtitle: 'Acceptable use, availability and liability',
                  document: termsOfService,
                ),
                _divider(context),
                _docTile(
                  context,
                  icon: LucideIcons.info,
                  title: financialDisclaimer.title,
                  subtitle: 'Estimates are not guarantees or advice',
                  document: financialDisclaimer,
                ),
                _divider(context),
                _docTile(
                  context,
                  icon: LucideIcons.toggleRight,
                  title: consentAndPermissionsDocument.title,
                  subtitle: 'Essential processing and optional choices',
                  document: consentAndPermissionsDocument,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(context, 'Your acceptance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: settings.hasAcceptedCurrentPolicies
                  ? _accepted(context, settings)
                  : _acceptanceForm(context, settings),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(context, 'Controls and help'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.toggleRight, size: 20),
                  title: const Text('Consent and permissions'),
                  subtitle: const Text(
                    'Review optional notifications and payment detection',
                  ),
                  trailing: _chevron(context),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConsentScreen()),
                  ),
                ),
                _divider(context),
                ListTile(
                  leading: const Icon(LucideIcons.database, size: 20),
                  title: const Text('Data controls'),
                  subtitle: const Text(
                    'Export, review deletion scope, or erase everything',
                  ),
                  trailing: _chevron(context),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DataControlsScreen(),
                    ),
                  ),
                ),
                _divider(context),
                ListTile(
                  leading: const Icon(LucideIcons.lifeBuoy, size: 20),
                  title: const Text('Support & complaints'),
                  subtitle: const Text(
                    'Bugs, incorrect calculations, privacy and security',
                  ),
                  trailing: _chevron(context),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  ),
                ),
                _divider(context),
                ListTile(
                  leading: const Icon(LucideIcons.smartphone, size: 20),
                  title: const Text('Device permissions and encryption'),
                  subtitle: const Text(
                    'What the app can access and whether storage is encrypted',
                  ),
                  trailing: _chevron(context),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
                _divider(context),
                ListTile(
                  leading: const Icon(LucideIcons.fileCode, size: 20),
                  title: const Text('Open-source licences'),
                  subtitle: const Text('Packages used by this build'),
                  trailing: _chevron(context),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'DailyMoney',
                    applicationVersion: kAppVersion,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel(context, 'About this build'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _aboutRow(
                    context,
                    'App version',
                    kAppVersion,
                  ),
                  const SizedBox(height: 8),
                  _aboutRow(
                    context,
                    'Policies',
                    'Version $kLegalVersion · $kLegalUpdatedOn',
                  ),
                  const SizedBox(height: 8),
                  _aboutRow(
                    context,
                    'Encryption at rest',
                    settings.encryptedAtRest ? 'On' : 'Unavailable',
                  ),
                  const SizedBox(height: 8),
                  _aboutRow(
                    context,
                    'Network',
                    'No internet permission',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This is a private-beta build. The policies and terms are '
                    'versioned for review and have not been certified by a '
                    'lawyer or regulator.',
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
        ],
      ),
    );
  }

  Widget _accepted(BuildContext context, SettingsProvider settings) {
    final scheme = Theme.of(context).colorScheme;
    final acceptedAt = DateTime.tryParse(settings.legalAcceptedAt ?? '');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.checkCircle2, size: 20, color: AppColors.income),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version $kLegalVersion accepted',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                acceptedAt == null
                    ? 'Acceptance is recorded on this device.'
                    : 'Recorded ${_dateLabel(acceptedAt)}. A newer version will '
                        'be shown for review.',
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
    );
  }

  Widget _acceptanceForm(BuildContext context, SettingsProvider settings) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review and accept version $kLegalVersion',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Both boxes are optional until you choose to accept. Nothing is '
          'preselected.',
          style: TextStyle(fontSize: 11.5, color: scheme.outline),
        ),
        const SizedBox(height: 8),
        _checkRow(
          context,
          value: _privacyRead,
          label: 'I have read the Privacy Policy',
          onChanged: (v) => setState(() => _privacyRead = v),
          onOpen: () => _open(privacyPolicy),
        ),
        _checkRow(
          context,
          value: _termsRead,
          label: 'I have read the Terms of Service',
          onChanged: (v) => setState(() => _termsRead = v),
          onOpen: () => _open(termsOfService),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _privacyRead && _termsRead
                ? () async {
                    await settings.acceptPolicies();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Policy acceptance recorded'),
                      ),
                    );
                  }
                : null,
            child: const Text('Accept current version'),
          ),
        ),
      ],
    );
  }

  Widget _checkRow(
    BuildContext context, {
    required bool value,
    required String label,
    required ValueChanged<bool> onChanged,
    required VoidCallback onOpen,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  decoration: TextDecoration.underline,
                  decorationColor: scheme.outline,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _docTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required LegalDocument document,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: _chevron(context),
      onTap: () => _open(document),
    );
  }

  Widget _aboutRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
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
        Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
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
        indent: 16,
        endIndent: 16,
        color:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      );

  Widget _chevron(BuildContext context) => Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: Theme.of(context).colorScheme.outline,
      );

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
}
