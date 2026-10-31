import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/daily_budget.dart';
import '../services/money_plan.dart';
import '../theme.dart';
import '../widgets/daily_money_footer.dart';

import '../utils/format.dart';
import '../widgets/plan_widgets.dart';
import 'goals_screen.dart';
import 'purchase_assistant_screen.dart';
import 'recovery_sheet.dart';
import 'what_if_screen.dart';

/// Explains the confirmed money left after bills, savings and the buffer.
class MoneyMapScreen extends StatelessWidget {
  const MoneyMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final txs = context.watch<TransactionsProvider>();
    final upcoming = context.watch<UpcomingProvider>();
    final goals = context.watch<GoalsProvider>();
    final currency = settings.currencyCode;
    final plan = MoneyPlan.compute(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
    );
    final snapshot = plan.snapshot;
    final daily = snapshot.hasBudget ? snapshot.allowance : plan.dailySafeLimit;
    final recoveryRunning =
        settings.recoveryActive && !settings.recoveryFinished(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Money map', style: TextStyle(color: scheme.onSurface)),
        actions: [
          IconButton(
            tooltip: 'Recovery plan',
            onPressed: () => _openRecovery(context),
            icon: const Icon(LucideIcons.heartPulse, size: 20),
          ),
          IconButton(
            tooltip: 'Savings goals',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GoalsScreen()),
            ),
            icon: const Icon(LucideIcons.target, size: 20),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          _Hero(plan: plan, daily: daily, currency: currency),
          const SizedBox(height: 12),
          if (plan.hasConfirmedBalance)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    PlanRow(
                      icon: LucideIcons.wallet,
                      label: 'Confirmed balance',
                      value: fmtMoney(plan.balance, currency),
                      note: 'Income minus every recorded expense and repayment',
                    ),
                    const Divider(height: 12),
                    PlanRow(
                      icon: LucideIcons.calendarClock,
                      label: 'Upcoming bills',
                      value: '-${fmtMoney(plan.billsReserved, currency)}',
                      note: 'Unpaid bills that still fall in this month',
                      color: AppColors.warn,
                    ),
                    PlanRow(
                      icon: LucideIcons.target,
                      label: 'Savings commitments',
                      value: '-${fmtMoney(plan.savingsCommitment, currency)}',
                      note: goals.active.isEmpty
                          ? 'No active goal has a target date'
                          : 'What your dated goals need this month',
                      color: AppColors.income,
                    ),
                    PlanRow(
                      icon: LucideIcons.shield,
                      label: 'Emergency buffer',
                      value: '-${fmtMoney(plan.emergencyBuffer, currency)}',
                      note: 'A planning reserve, not a bank transfer',
                    ),
                    const Divider(height: 14),
                    PlanRow(
                      icon: LucideIcons.badgeCheck,
                      label: 'Safe to spend',
                      value: fmtMoney(plan.safeToSpend, currency),
                      emphasized: true,
                      color: plan.safeToSpend > 0
                          ? scheme.primary
                          : AppColors.expense,
                      note: 'The confirmed money that is genuinely available',
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    PlanRow(
                      icon: LucideIcons.wallet,
                      label: 'Monthly budget',
                      value: fmtMoney(snapshot.budget, currency),
                      note: 'No positive confirmed balance is recorded yet',
                    ),
                    PlanRow(
                      icon: LucideIcons.trendingDown,
                      label: 'Spent this month',
                      value: '-${fmtMoney(snapshot.monthExpense, currency)}',
                      color: AppColors.expense,
                    ),
                    PlanRow(
                      icon: LucideIcons.calendarClock,
                      label: 'Upcoming bills',
                      value: '-${fmtMoney(plan.billsReserved, currency)}',
                      color: AppColors.warn,
                    ),
                    const Divider(height: 14),
                    PlanRow(
                      icon: LucideIcons.calculator,
                      label: 'Budget left',
                      value: fmtMoney(snapshot.monthlyLeft, currency),
                      emphasized: true,
                      color: snapshot.monthlyLeft < 0
                          ? AppColors.expense
                          : scheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          PlanNote(
            icon: LucideIcons.landmark,
            text: plan.hasConfirmedBalance
                ? 'Safe to spend is calculated, not transferred. Your bank '
                    'balance is unchanged; bills, savings and the buffer are '
                    'simply kept out of the daily plan.'
                : 'Record your income to unlock balance-based protection. Until '
                    'then the plan uses your monthly budget, so no cash is '
                    'assumed.',
          ),
          const SizedBox(height: 20),
          const PlanSectionTitle(title: 'Today'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  if (!snapshot.hasBudget)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No monthly budget yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A budget turns your confirmed money into a daily '
                          'number you can act on.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: scheme.outline,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _editBudget(context, settings),
                          icon: const Icon(LucideIcons.plus, size: 17),
                          label: const Text('Set monthly budget'),
                        ),
                      ],
                    )
                  else ...[
                    PlanRow(
                      label: 'Allowance before adjustments',
                      value: fmtMoney(snapshot.baseAllowance, currency),
                      note: snapshot.policy.description,
                    ),
                    if (snapshot.protectionApplied)
                      PlanRow(
                        label: 'Money protection cap',
                        value:
                            '-${fmtMoney(_protectionEffect(snapshot), currency)}',
                        color: scheme.primary,
                        icon: LucideIcons.shieldCheck,
                      ),
                    if (snapshot.recoveryApplied)
                      PlanRow(
                        label: 'Recovery plan',
                        value: '-${fmtMoney(snapshot.recoveryCut, currency)}',
                        color: AppColors.warn,
                        icon: LucideIcons.heartPulse,
                      ),
                    const Divider(height: 14),
                    PlanRow(
                      label: "Today's allowance",
                      value: fmtMoney(snapshot.allowance, currency),
                      emphasized: true,
                    ),
                    PlanRow(
                      label: 'Spent today',
                      value: '-${fmtMoney(snapshot.spentToday, currency)}',
                      color: AppColors.expense,
                    ),
                    PlanRow(
                      label: snapshot.remainingToday < 0
                          ? 'Over today'
                          : 'Left today',
                      value: fmtMoney(snapshot.remainingToday.abs(), currency),
                      emphasized: true,
                      color: snapshot.remainingToday < 0
                          ? AppColors.expense
                          : scheme.primary,
                    ),
                    if (snapshot.adjustmentReason != null) ...[
                      const SizedBox(height: 6),
                      PlanNote(
                        icon: LucideIcons.info,
                        text: snapshot.adjustmentReason!,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const PlanSectionTitle(
            title: 'Protection & policy',
            subtitle: 'Control how unused money and reserved money behave.',
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.moneyProtection,
                  onChanged: (v) =>
                      context.read<SettingsProvider>().setMoneyProtection(v),
                  secondary: const Icon(LucideIcons.shieldCheck, size: 20),
                  title: const Text('Money protection'),
                  subtitle: const Text(
                    'Never plan more than the confirmed money left',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.repeat, size: 20),
                  title: const Text('Unused allowance'),
                  subtitle: Text(settings.allowancePolicy.description),
                  trailing: Text(
                    settings.allowancePolicy.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  onTap: () => _pickPolicy(context, settings),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.shield, size: 20),
                  title: const Text('Emergency buffer'),
                  subtitle: const Text(
                    'Kept out of daily spending until you change it',
                  ),
                  trailing: Text(
                    fmtMoney(settings.emergencyBuffer, currency),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: settings.emergencyBuffer > 0
                          ? scheme.primary
                          : scheme.outline,
                    ),
                  ),
                  onTap: () => _editBuffer(context, settings),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.target, size: 20),
                  title: const Text('Savings commitments'),
                  subtitle: Text(
                    goals.active.where((g) => g.targetDate != null).isEmpty
                        ? 'Add a target date to a goal to protect its monthly need'
                        : 'Monthly needs of your dated goals',
                  ),
                  trailing: Text(
                    fmtMoney(plan.savingsCommitment, currency),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const PlanSectionTitle(
            title: 'Try a decision',
            subtitle: 'Simulate before you spend. Nothing is recorded.',
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WhatIfScreen()),
                  ),
                  icon: const Icon(LucideIcons.gitBranch, size: 17),
                  label: const Text('What if?'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PurchaseAssistantScreen(),
                    ),
                  ),
                  icon: const Icon(LucideIcons.shoppingBag, size: 17),
                  label: const Text('Can I buy it?'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.heartPulse, size: 20),
              title: Text(
                recoveryRunning ? 'Recovery plan is active' : 'Recovery plan',
              ),
              subtitle: Text(
                recoveryRunning
                    ? 'Day ${settings.recoveryDayNumber(DateTime.now())} · '
                        '${fmtMoney(settings.recoveryDailyCut, currency)} less '
                        'per day'
                    : snapshot.monthlyLeft < 0 || snapshot.remainingToday < 0
                        ? 'Spread the overspend over a short, realistic window'
                        : 'Not needed right now',
              ),
              trailing: Icon(LucideIcons.chevronRight,
                  size: 18, color: scheme.outline),
              onTap: () => _openRecovery(context),
            ),
          ),
          const DailyMoneyFooter(),
        ],
      ),
    );
  }

  double _protectionEffect(DailyBudgetSnapshot snapshot) {
    final effect =
        snapshot.baseAllowance - (snapshot.allowance + snapshot.recoveryCut);
    return effect < 0 ? 0 : effect;
  }

  Future<void> _editBudget(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final value = await showAmountDialog(
      context,
      title: 'Monthly budget',
      label: 'Amount',
      currencyCode: settings.currencyCode,
      initial: settings.monthlyBudget,
      helper: 'Used to split the month into a daily allowance.',
    );
    if (value == null || !context.mounted) return;
    await context.read<SettingsProvider>().setMonthlyBudget(value);
  }

  Future<void> _editBuffer(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final controller = TextEditingController(
      text: settings.emergencyBuffer > 0
          ? fmtAmountInput(settings.emergencyBuffer)
          : '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency buffer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount to keep back',
            helperText: 'Set 0 to remove the buffer.',
            prefixText: '${currencyByCode(settings.currencyCode).symbol} ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = parseAmount(controller.text);
              Navigator.pop(ctx, parsed ?? 0);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    await context.read<SettingsProvider>().setEmergencyBuffer(value);
  }

  Future<void> _pickPolicy(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final picked = await showDialog<AllowancePolicy>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Unused allowance'),
        children: [
          for (final policy in AllowancePolicy.values)
            ListTile(
              onTap: () => Navigator.pop(ctx, policy),
              title: Text(policy.label),
              subtitle: Text(policy.description),
              trailing: settings.allowancePolicy == policy
                  ? Icon(
                      LucideIcons.check,
                      size: 19,
                      color: Theme.of(ctx).colorScheme.primary,
                    )
                  : null,
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    await context.read<SettingsProvider>().setAllowancePolicy(picked);
  }

  void _openRecovery(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const RecoverySheet(),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.plan,
    required this.daily,
    required this.currency,
  });

  final MoneyPlan plan;
  final double daily;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final amount =
        plan.hasConfirmedBalance ? plan.safeToSpend : plan.availableToSpend;
    final protected =
        plan.hasConfirmedBalance ? plan.protectedTotal : plan.billsReserved;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12B98A), Color(0xFF0B7A61)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B7A61).withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                plan.hasConfirmedBalance
                    ? LucideIcons.badgeCheck
                    : LucideIcons.calculator,
                size: 17,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 7),
              Text(
                plan.hasConfirmedBalance
                    ? 'Safe to spend'
                    : 'Budget left to plan',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fmtMoney(amount, currency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _pill(
                label: plan.hasConfirmedBalance
                    ? 'Confirmed balance'
                    : 'Monthly budget',
                value: fmtMoney(
                  plan.hasConfirmedBalance
                      ? plan.balance
                      : plan.snapshot.budget,
                  currency,
                ),
              ),
              const SizedBox(width: 8),
              _pill(
                label: 'Protected',
                value: fmtMoney(protected, currency),
              ),
              const SizedBox(width: 8),
              _pill(
                label: 'Per day',
                value: fmtMoney(daily, currency),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
