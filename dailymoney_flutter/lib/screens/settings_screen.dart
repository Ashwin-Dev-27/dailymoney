import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/capture_provider.dart';
import '../providers/expected_income_provider.dart';
import '../providers/security_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shared_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/capture_setup.dart';
import '../services/demo_seed.dart';
import '../services/legal_content.dart';
import '../services/sound_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/daily_money_footer.dart';

import '../utils/format.dart';
import 'capture_screen.dart';
import 'consent_screen.dart';
import 'expected_income_screen.dart';
import 'help_centre_screen.dart';
import 'import_screen.dart';
import 'legal_hub_screen.dart';
import 'money_map_screen.dart';
import 'patterns_screen.dart';
import 'pin_setup_screen.dart';
import 'privacy_screen.dart';
import 'shared_screen.dart';
import 'student_screen.dart';
import 'support_screen.dart';
import 'what_if_screen.dart';

/// Preferences: currency, budget, notifications, theme and data management.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.budgetAnchor,
    this.whatIfAnchor,
    this.nightSummaryAnchor,
    this.privacyAnchor,
    this.dataAnchor,
  });

  /// Optional targets used by the guided tour.
  final GlobalKey? budgetAnchor;
  final GlobalKey? whatIfAnchor;
  final GlobalKey? nightSummaryAnchor;
  final GlobalKey? privacyAnchor;
  final GlobalKey? dataAnchor;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _budget;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _budget = TextEditingController(
      text: settings.monthlyBudget == 0
          ? ''
          : fmtAmountInput(settings.monthlyBudget),
    );
    _name = TextEditingController(text: settings.userName);
  }

  @override
  void dispose() {
    _budget.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveBudget(String v) async {
    final text = v.trim();
    final parsed = parseAmount(text);
    final settings = context.read<SettingsProvider>();
    if (text.isNotEmpty && parsed == null) {
      SoundService.instance.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid budget amount')),
      );
      return;
    }
    final value = (parsed ?? 0) < 0 ? 0.0 : (parsed ?? 0);
    if ((value - settings.monthlyBudget).abs() < 0.005) return;
    await settings.setMonthlyBudget(value);
    SoundService.instance.budgetConfirm();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value > 0
              ? 'Monthly budget set to ${fmtMoney(value, settings.currencyCode)}'
              : 'Monthly budget removed'),
        ),
      );
    }
  }

  Future<void> _saveName(String v) async {
    final settings = context.read<SettingsProvider>();
    if (v.trim() == settings.userName) return;
    await settings.setUserName(v);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.userName.isEmpty
              ? 'Greeting name cleared'
              : 'Greetings will use your name'),
        ),
      );
    }
  }

  Future<void> _loadDemoData() async {
    final confirmed = await _confirm(
      'Load demo data',
      'Adds around 85 sample transactions for the last 4 months. '
          'Existing entries are kept.',
      confirmLabel: 'Load demo',
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<TransactionsProvider>();
    final txs = DemoSeed().generate();
    await provider.addAll(txs);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${txs.length} demo transactions added')),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await _confirm(
      'Delete all transactions',
      'This permanently removes every transaction from this device. This cannot be undone.',
      confirmLabel: 'Delete all',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final shared = context.read<SharedProvider>();
    final n = await context.read<TransactionsProvider>().removeAll();
    await shared.removeAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n transactions deleted')),
      );
    }
  }

  Future<void> _clearUpcoming() async {
    final confirmed = await _confirm(
      'Delete all upcoming bills',
      'This removes every tracked bill from this device. Recorded transactions are kept.',
      confirmLabel: 'Delete bills',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final n = await context.read<UpcomingProvider>().removeAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n upcoming bills deleted')),
      );
    }
  }

  Future<bool> _ensureNotifications() async {
    if (!NotificationService.isReady) {
      _snack('Notifications are unavailable on this device.');
      return false;
    }
    final granted = await NotificationService.requestPermission();
    if (!granted && mounted) {
      _snack('Allow notifications in Android settings to receive briefings.');
    }
    return granted;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _setMorning(bool value) async {
    if (value && !await _ensureNotifications()) return;
    if (!mounted) return;
    await context.read<SettingsProvider>().setMorningBriefing(value);
  }

  Future<void> _setNight(bool value) async {
    if (value && !await _ensureNotifications()) return;
    if (!mounted) return;
    await context.read<SettingsProvider>().setNightSummary(value);
  }

  Future<void> _setAlerts(bool value) async {
    if (value && !await _ensureNotifications()) return;
    if (!mounted) return;
    await context.read<SettingsProvider>().setBudgetAlerts(value);
  }

  Future<void> _pickTime({required bool morning}) async {
    final settings = context.read<SettingsProvider>();
    final picked = await showTimePicker(
      context: context,
      initialTime: morning ? settings.morningTime : settings.nightTime,
    );
    if (picked == null || !mounted) return;
    if (morning) {
      await settings.setMorningTime(picked);
    } else {
      await settings.setNightTime(picked);
    }
  }

  Future<void> _togglePin(bool value) async {
    final security = context.read<SecurityProvider>();
    if (value) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (ok == true) _snack('App lock enabled');
      return;
    }
    final confirmed = await _confirm(
      'Turn off app lock',
      'Anyone with this phone will be able to open DailyMoney and see your '
          'records.',
      confirmLabel: 'Turn off',
      destructive: true,
    );
    if (confirmed != true) return;
    await security.disablePin();
    _snack('App lock removed');
  }

  Future<void> _changePin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PinSetupScreen(requireCurrent: true),
      ),
    );
    if (ok == true) _snack('PIN changed');
  }

  Future<void> _toggleBiometric(bool value) async {
    final security = context.read<SecurityProvider>();
    if (value && !security.biometricAvailable) {
      _snack('Set up a fingerprint or face unlock in Android first.');
      return;
    }
    final ok = await security.setBiometric(value);
    if (!mounted) return;
    _snack(
      ok
          ? (value ? 'Biometric unlock enabled' : 'Biometric unlock disabled')
          : 'Biometric unlock was not enabled',
    );
  }

  Future<void> _pickAutoLock() async {
    final security = context.read<SecurityProvider>();
    const options = <int, String>{
      0: 'Immediately',
      15: 'After 15 seconds',
      60: 'After 1 minute',
      300: 'After 5 minutes',
    };
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Lock DailyMoney',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            for (final entry in options.entries)
              ListTile(
                leading: Icon(
                  security.autoLockSeconds == entry.key
                      ? LucideIcons.check
                      : LucideIcons.shieldCheck,
                  size: 20,
                ),
                title: Text(entry.value),
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await security.setAutoLockSeconds(selected);
  }

  Future<void> _setAutoCapture(bool value) async {
    await CaptureSetup.setEnabled(context, value);
  }

  Future<void> _openCapture() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
    if (mounted) {
      await context.read<CaptureProvider>().refresh(
            acceptNative: context.read<SettingsProvider>().autoCapture,
          );
    }
  }

  Future<void> _openImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportScreen()),
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyScreen()),
    );
  }

  void _openLegalHub() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LegalHubScreen()),
    );
  }

  void _openConsent() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConsentScreen()),
    );
  }

  void _openSupport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SupportScreen()),
    );
  }

  void _openHelpCentre() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HelpCentreScreen()),
    );
  }

  Future<void> _replayTutorial() async {
    await context.read<SettingsProvider>().replayTutorial();
  }

  Widget _soundPreviewButton(BuildContext context, String label, String asset) {
    return OutlinedButton(
      onPressed: () => SoundService.instance.preview(asset),
      child: Text(label),
    );
  }

  Future<void> _resetTutorial() async {
    final confirmed = await _confirm(
      'Show the welcome and tour again?',
      'This only resets onboarding. Your transactions, bills, goals, budget, '
          'preferences and app-lock PIN are kept.',
      confirmLabel: 'Show welcome',
    );
    if (confirmed != true || !mounted) return;
    await context.read<SettingsProvider>().resetTutorialProgress();
  }

  String _autoLockLabel(int seconds) => switch (seconds) {
        0 => 'Immediately',
        15 => '15 seconds',
        60 => '1 minute',
        300 => '5 minutes',
        _ => '$seconds seconds',
      };

  Future<bool?> _confirm(
    String title,
    String message, {
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.expense)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final txCount = context.watch<TransactionsProvider>().count;
    final upcomingCount = context.watch<UpcomingProvider>().count;
    final security = context.watch<SecurityProvider>();
    final capture = context.watch<CaptureProvider>();
    final expected = context.watch<ExpectedIncomeProvider>();
    final shared = context.watch<SharedProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: scheme.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          _sectionLabel(context, 'Account & preferences'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  // Greeting name
                  Row(
                    children: [
                      const Icon(LucideIcons.user, size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Your name',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: TextField(
                          controller: _name,
                          textAlign: TextAlign.end,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _saveName,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                            _saveName(_name.text);
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Optional',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  // Currency
                  Row(
                    children: [
                      const Icon(LucideIcons.globe, size: 20),
                      const SizedBox(width: 14),
                      Text(
                        'Currency',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Let the dropdown take the remaining width and ellipsize
                      // long currency names on narrow phones.
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: settings.currencyCode,
                            isExpanded: true,
                            alignment: Alignment.centerRight,
                            borderRadius: BorderRadius.circular(14),
                            items: [
                              for (final c in kCurrencies)
                                DropdownMenuItem(
                                  value: c.code,
                                  child: Text(
                                    '${c.code} · ${c.symbol} ${c.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                context.read<SettingsProvider>().setCurrency(v);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  // Monthly budget
                  KeyedSubtree(
                    key: widget.budgetAnchor,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.wallet, size: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Monthly budget',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _budget,
                            textAlign: TextAlign.end,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]')),
                            ],
                            onSubmitted: _saveBudget,
                            onTapOutside: (_) {
                              FocusScope.of(context).unfocus();
                              _saveBudget(_budget.text);
                            },
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'None',
                              suffixText:
                                  currencyByCode(settings.currencyCode).symbol,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: settings.carryForward,
                    onChanged: (v) =>
                        context.read<SettingsProvider>().setCarryForward(v),
                    secondary: const Icon(LucideIcons.repeat, size: 20),
                    title: const Text('Carry forward unused money'),
                    subtitle: const Text(
                      "Roll today's leftover allowance into tomorrow",
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Planning'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.map, size: 20),
                  title: const Text('Money map & protection'),
                  subtitle: Text(
                    '${settings.moneyProtection ? 'Protection on' : 'Protection off'} · '
                    '${settings.allowancePolicy.label}',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MoneyMapScreen()),
                  ),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.calendarClock, size: 20),
                  title: const Text('Expected income'),
                  subtitle: Text(
                    expected.pending.isEmpty
                        ? 'Nothing waiting for confirmation'
                        : '${expected.pending.length} waiting · '
                            '${fmtMoney(expected.pendingTotal, settings.currencyCode)} '
                            'not counted',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExpectedIncomeScreen(),
                    ),
                  ),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.users, size: 20),
                  title: const Text('Shared expenses'),
                  subtitle: Text(
                    shared.isEmpty
                        ? 'Split a bill or track money owed'
                        : '${fmtMoney(shared.owedToMe, settings.currencyCode)} '
                            'owed to you · '
                            '${fmtMoney(shared.iOwe, settings.currencyCode)} '
                            'you owe',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SharedScreen()),
                  ),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.scanSearch, size: 20),
                  title: const Text('Patterns & habits'),
                  subtitle: const Text(
                    'Evidence-backed observations from your records',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PatternsScreen()),
                  ),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                SwitchListTile(
                  value: settings.studentMode,
                  onChanged: (v) =>
                      context.read<SettingsProvider>().setStudentMode(v),
                  secondary: const Icon(LucideIcons.graduationCap, size: 20),
                  title: const Text('Student mode'),
                  subtitle: const Text(
                    'Weekly view plus pocket money, hostel and study categories',
                  ),
                ),
                if (settings.studentMode) ...[
                  Divider(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      height: 1,
                      indent: 16,
                      endIndent: 16),
                  ListTile(
                    leading: const Icon(LucideIcons.graduationCap, size: 20),
                    title: const Text('Student tools'),
                    subtitle: const Text(
                      'Allowance, quick records and money coming',
                    ),
                    trailing: Icon(LucideIcons.chevronRight,
                        size: 18, color: scheme.outline),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StudentScreen()),
                    ),
                  ),
                ],
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  key: widget.whatIfAnchor,
                  leading: const Icon(LucideIcons.gitBranch, size: 20),
                  title: const Text('What if & purchase check'),
                  subtitle: const Text(
                    'Simulate a choice before money is spent',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WhatIfScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Privacy & security'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: security.pinEnabled,
                  onChanged: _togglePin,
                  secondary: const Icon(LucideIcons.lock, size: 20),
                  title: const Text('App lock'),
                  subtitle: Text(
                    security.pinEnabled
                        ? 'Ask for a PIN when DailyMoney opens'
                        : 'Off · anyone with this phone can open the app',
                  ),
                ),
                if (security.pinEnabled) ...[
                  Divider(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      height: 1),
                  ListTile(
                    leading: const Icon(LucideIcons.lock, size: 20),
                    title: const Text('Change PIN'),
                    trailing: Icon(LucideIcons.chevronRight,
                        size: 18, color: scheme.outline),
                    onTap: _changePin,
                  ),
                  Divider(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      height: 1),
                  SwitchListTile(
                    value: security.biometricEnabled,
                    onChanged:
                        security.biometricAvailable ? _toggleBiometric : null,
                    secondary: const Icon(LucideIcons.fingerprint, size: 20),
                    title: const Text('Unlock with biometrics'),
                    subtitle: Text(
                      security.biometricAvailable
                          ? 'Fingerprint or face, when available'
                          : 'No biometrics enrolled on this device',
                    ),
                  ),
                  Divider(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      height: 1),
                  ListTile(
                    leading: const Icon(LucideIcons.shieldCheck, size: 20),
                    title: const Text('Auto-lock'),
                    subtitle: const Text(
                      'Lock after the app has been in the background',
                    ),
                    trailing: Text(
                      _autoLockLabel(security.autoLockSeconds),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    onTap: _pickAutoLock,
                  ),
                ],
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1),
                SwitchListTile(
                  value: settings.blockScreenshots,
                  onChanged: (v) => settings.setBlockScreenshots(v),
                  secondary: const Icon(LucideIcons.eyeOff, size: 20),
                  title: const Text('Block screenshots'),
                  subtitle: const Text(
                    'Hide balances from screenshots and the recent-apps preview',
                  ),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1),
                ListTile(
                  key: widget.privacyAnchor,
                  leading: const Icon(LucideIcons.shieldCheck, size: 20),
                  title: const Text('Permissions & data'),
                  subtitle: Text(
                    settings.encryptedAtRest
                        ? 'Encrypted at rest · export or erase your data'
                        : 'Export or erase your data',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: _openPrivacy,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Payment detection'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.autoCapture,
                  onChanged: _setAutoCapture,
                  secondary: const Icon(LucideIcons.radar, size: 20),
                  title: const Text('Detect payments in notifications'),
                  subtitle: const Text(
                    'Review each one before it enters your ledger',
                  ),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1),
                ListTile(
                  leading: const Icon(LucideIcons.bell, size: 20),
                  title: const Text('Detected payments'),
                  subtitle: Text(
                    capture.count == 0
                        ? 'Nothing waiting for review'
                        : '${capture.count} waiting · '
                            '${fmtMoney(capture.pendingExpenseTotal, settings.currencyCode)} '
                            'in expenses',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (capture.count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warn.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${capture.count}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warn,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Icon(LucideIcons.chevronRight,
                          size: 18, color: scheme.outline),
                    ],
                  ),
                  onTap: _openCapture,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.info, size: 13, color: scheme.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Reads notifications from other apps, but only keeps '
                          'ones that look like a payment and contain an '
                          'amount. Nothing is sent off the phone or added to '
                          'your ledger until you confirm it.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.outline,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Import & statements'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.fileSpreadsheet, size: 20),
                  title: const Text('Import bank statement'),
                  subtitle: const Text(
                    'Paste a CSV export from your bank or UPI app',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: _openImport,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.info, size: 13, color: scheme.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Direct bank linking needs a regulated bank or '
                          'Account Aggregator service. Statement import gives '
                          'you the same history offline, with no account or '
                          'cloud connection.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.outline,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.morningBriefing,
                  onChanged: _setMorning,
                  secondary: const Icon(LucideIcons.sun, size: 20),
                  title: const Text('Morning greeting'),
                  subtitle: Text(
                    'Daily allowance at ${settings.morningTime.format(context)}',
                  ),
                ),
                _timeRow(
                  context,
                  label: 'Greeting time',
                  time: settings.morningTime,
                  enabled: settings.morningBriefing,
                  onTap: () => _pickTime(morning: true),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                SwitchListTile(
                  key: widget.nightSummaryAnchor,
                  value: settings.nightSummary,
                  onChanged: _setNight,
                  secondary: const Icon(LucideIcons.moon, size: 20),
                  title: const Text('Nightly summary'),
                  subtitle: Text(
                    'Spent today and allowance left at ${settings.nightTime.format(context)}',
                  ),
                ),
                _timeRow(
                  context,
                  label: 'Summary time',
                  time: settings.nightTime,
                  enabled: settings.nightSummary,
                  onTap: () => _pickTime(morning: false),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                SwitchListTile(
                  value: settings.budgetAlerts,
                  onChanged: _setAlerts,
                  secondary: const Icon(LucideIcons.bell, size: 20),
                  title: const Text('Budget alerts'),
                  subtitle: const Text(
                    'Notify when 80% of the daily allowance is used or it is exceeded',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.info, size: 13, color: scheme.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Briefings use the latest numbers whenever you open '
                          'the app or change a transaction.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.outline,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(LucideIcons.monitor, size: 15),
                          label: Text('System')),
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(LucideIcons.sun, size: 15),
                          label: Text('Light')),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(LucideIcons.moon, size: 15),
                          label: Text('Dark')),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) =>
                        context.read<SettingsProvider>().setThemeMode(s.first),
                    showSelectedIcon: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Help & support'),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('settings-help-centre'),
                  leading: const Icon(LucideIcons.bookOpen, size: 20),
                  title: const Text('Help centre'),
                  subtitle: const Text(
                    'User guide, FAQ and guided tour',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: _openHelpCentre,
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.shieldCheck, size: 20),
                  title: const Text('Legal & privacy'),
                  subtitle: Text(
                    settings.hasAcceptedCurrentPolicies
                        ? 'Policies v$kLegalVersion accepted · review or update'
                        : 'Privacy, terms, disclaimer and acceptance',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: _openLegalHub,
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.toggleRight, size: 20),
                  title: const Text('Consent and permissions'),
                  subtitle: const Text(
                    'Optional notifications and payment detection',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: _openConsent,
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.lifeBuoy, size: 20),
                  title: const Text('Support & complaints'),
                  subtitle: const Text(
                    'Bugs, incorrect calculations, privacy and security',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: _openSupport,
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(LucideIcons.play, size: 20),
                  title: const Text('Show intro animation'),
                  subtitle: const Text(
                    'Cinematic splash on launch. Turn off for a faster start.',
                  ),
                  value: settings.splashIntroEnabled,
                  onChanged: (v) =>
                      context.read<SettingsProvider>().setSplashIntroEnabled(v),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.compass, size: 20),
                  title: const Text('Replay guided tour'),
                  subtitle: const Text(
                    'A short, skippable walkthrough of the main controls',
                  ),
                  trailing: Icon(LucideIcons.chevronRight,
                      size: 18, color: scheme.outline),
                  onTap: _replayTutorial,
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.rotateCcw, size: 20),
                  title: const Text('Show welcome and tour again'),
                  subtitle: const Text(
                    'Resets onboarding only; your records stay untouched',
                  ),
                  onTap: _resetTutorial,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Sound & haptics'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(LucideIcons.volume2, size: 20),
                  title: const Text('Sound effects'),
                  subtitle: const Text('Soft UI sounds for meaningful actions'),
                  value: settings.soundEnabled,
                  onChanged: (v) =>
                      context.read<SettingsProvider>().setSoundEnabled(v),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.volume1, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          value: settings.soundVolume,
                          onChanged: settings.soundEnabled
                              ? (v) => context
                                  .read<SettingsProvider>()
                                  .setSoundVolume(v)
                              : null,
                        ),
                      ),
                      Text('${(settings.soundVolume * 100).round()}%'),
                    ],
                  ),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(LucideIcons.smartphone, size: 20),
                  title: const Text('Haptics'),
                  subtitle: const Text('Gentle vibration feedback'),
                  value: settings.hapticsEnabled,
                  onChanged: (v) =>
                      context.read<SettingsProvider>().setHapticsEnabled(v),
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _soundPreviewButton(context, 'Click', 'click.wav'),
                      _soundPreviewButton(context, 'Pop', 'pop.wav'),
                      _soundPreviewButton(
                          context, 'Success', 'chime_success.wav'),
                      _soundPreviewButton(context, 'Tick', 'tick.wav'),
                      _soundPreviewButton(context, 'Error', 'error.wav'),
                      _soundPreviewButton(context, 'Delete', 'delete.wav'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Data management'),
          Card(
            key: widget.dataAnchor,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.sparkles, size: 20),
                  title: const Text('Load demo data'),
                  subtitle: const Text('Sample activity for the last 4 months'),
                  onTap: _loadDemoData,
                ),
                Divider(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                    indent: 16,
                    endIndent: 16),
                ListTile(
                  leading: const Icon(
                    LucideIcons.trash2,
                    size: 20,
                    color: AppColors.expense,
                  ),
                  title: const Text(
                    'Delete all transactions',
                    style: TextStyle(color: AppColors.expense),
                  ),
                  subtitle: Text('$txCount stored on this device'),
                  onTap: txCount == 0 ? null : _clearAll,
                ),
                if (upcomingCount > 0) ...[
                  Divider(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      height: 1,
                      indent: 16,
                      endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      LucideIcons.calendarClock,
                      size: 20,
                      color: AppColors.expense,
                    ),
                    title: const Text(
                      'Delete all upcoming bills',
                      style: TextStyle(color: AppColors.expense),
                    ),
                    subtitle: Text('$upcomingCount tracked bills'),
                    onTap: _clearUpcoming,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const DailyMoneyFooter(),
        ],
      ),
    );
  }

  Widget _timeRow(
    BuildContext context, {
    required String label,
    required TimeOfDay time,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.only(left: 56, right: 8),
      dense: true,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: enabled ? scheme.outline : scheme.outlineVariant,
        ),
      ),
      trailing: TextButton(
        onPressed: enabled ? onTap : null,
        child: Text(
          time.format(context),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
