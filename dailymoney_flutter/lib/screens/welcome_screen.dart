import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/demo_seed.dart';
import '../services/legal_content.dart';
import '../theme.dart';
import 'legal_document_screen.dart';

/// First-run welcome gate. The tour is optional and can be skipped or replayed.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _accepted = false;
  bool _sampleData = false;
  bool _working = false;

  Future<void> _continue({required bool tour}) async {
    if (!_accepted || _working) return;
    final settings = context.read<SettingsProvider>();
    final txs = context.read<TransactionsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final goals = context.read<GoalsProvider>();
    setState(() => _working = true);
    if (!settings.hasAcceptedCurrentPolicies) {
      await settings.acceptPolicies();
    }
    if (_sampleData && txs.isEmpty) {
      final demo = DemoSeed();
      await txs.addAll(demo.generate());
      if (upcoming.isEmpty) await upcoming.addAll(demo.generateUpcoming());
      if (goals.isEmpty) await goals.addAll(demo.generateGoals());
    }
    await settings.markSeeded();
    if (tour) {
      await settings.startTutorial();
    } else {
      await settings.dismissWelcome();
    }
    if (mounted) setState(() => _working = false);
  }

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
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                  maxWidth: 520,
                ),
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            LucideIcons.wallet,
                            size: 34,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Welcome to DailyMoney!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Let\'s make managing your money simple.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          color: scheme.outline,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            children: [
                              _feature(
                                context,
                                icon: LucideIcons.calendarDays,
                                title: 'Know what is safe to spend today',
                                body: 'A daily allowance based on your budget '
                                    'and the bills already set aside.',
                              ),
                              const SizedBox(height: 12),
                              _feature(
                                context,
                                icon: LucideIcons.target,
                                title: 'Plan before money moves',
                                body: 'Bills, goals and what-if scenarios, all '
                                    'on the same page as your ledger.',
                              ),
                              const SizedBox(height: 12),
                              _feature(
                                context,
                                icon: LucideIcons.shieldCheck,
                                title: 'Your records stay on this phone',
                                body: 'No account, no cloud sync, no analytics '
                                    'and no internet permission.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (context.watch<TransactionsProvider>().isEmpty)
                        CheckboxListTile(
                          value: _sampleData,
                          onChanged: (v) =>
                              setState(() => _sampleData = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Start with sample data',
                            style: TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                          subtitle: const Text(
                            'Adds about 85 example transactions, a few bills '
                            'and two goals so charts have content. Off by '
                            'default, and deletable in Settings > Data management.',
                            style: TextStyle(fontSize: 11, height: 1.45),
                          ),
                        ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _accepted,
                        onChanged: (v) =>
                            setState(() => _accepted = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'I have read and agree to the Terms of Service and '
                          'Privacy Policy.',
                          style: TextStyle(fontSize: 12.5, height: 1.4),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            children: [
                              TextButton(
                                onPressed: () => _open(privacyPolicy),
                                child: const Text('Privacy Policy'),
                              ),
                              TextButton(
                                onPressed: () => _open(termsOfService),
                                child: const Text('Terms of Service'),
                              ),
                              TextButton(
                                onPressed: () => _open(financialDisclaimer),
                                child: const Text('Disclaimer'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _accepted && !_working
                            ? () => _continue(tour: true)
                            : null,
                        child: const Text('Take a quick tour'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _accepted && !_working
                            ? () => _continue(tour: false)
                            : null,
                        child: const Text('Explore myself'),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'The tour is optional and can be skipped. You can '
                        'replay it later in Settings. Optional permissions are '
                        'requested only when you turn on the related feature.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: scheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your acceptance is recorded on this device with the '
                        'policy version and time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.4,
                          color: scheme.outline.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _feature(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: AppColors.brand),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
