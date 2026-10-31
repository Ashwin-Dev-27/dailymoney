import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/savings_goal.dart';
import '../models/upcoming_expense.dart';
import '../providers/capture_provider.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/daily_budget.dart';
import '../services/missing_expense.dart';
import '../services/money_plan.dart';
import '../theme.dart';
import '../widgets/daily_money_footer.dart';

import '../utils/format.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/upcoming_tile.dart';
import '../widgets/empty_state.dart';
import 'assistant_screen.dart';
import 'capture_screen.dart';
import 'expected_income_screen.dart';
import 'goal_sheet.dart';
import 'goals_screen.dart';
import 'money_map_screen.dart';
import 'missing_expense_sheet.dart';
import 'patterns_screen.dart';
import 'recovery_sheet.dart';
import 'reports_screen.dart';
import 'shared_screen.dart';
import 'student_screen.dart';
import 'upcoming_screen.dart';
import 'upcoming_sheet.dart';
import 'what_if_screen.dart';

/// Dashboard: balance, daily spending money, budget pace, upcoming bills and
/// recent activity.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onSeeAll,
    required this.onOpenSettings,
    this.overviewAnchor,
    this.allowanceAnchor,
  });

  /// Switch the shell to the transactions tab.
  final VoidCallback onSeeAll;

  /// Switch the shell to the settings tab.
  final VoidCallback onOpenSettings;

  /// Optional targets used by the guided tour.
  final GlobalKey? overviewAnchor;
  final GlobalKey? allowanceAnchor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final txs = context.watch<TransactionsProvider>();
    final upcoming = context.watch<UpcomingProvider>();
    final goals = context.watch<GoalsProvider>();
    final capture = context.watch<CaptureProvider>();
    final now = DateTime.now();
    final month = monthOf(now);
    final totals = txs.totalsFor(month);
    final balance = txs.balance;
    final plan = MoneyPlan.compute(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
    );
    final snapshot = plan.snapshot;
    final nextBills = upcoming.nextUpcoming();
    final missingCheck = MissingExpenseDetector.check(
      transactions: txs.all,
      settings: settings,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                LucideIcons.wallet,
                size: 18,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: 10),
            Text('DailyMoney', style: TextStyle(color: scheme.onSurface)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Money assistant',
            onPressed: () => _openAssistant(context),
            icon: const Icon(LucideIcons.sparkles, size: 20),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
        children: [
          if (capture.count > 0) ...[
            _CaptureBanner(
              count: capture.count,
              total: capture.pendingExpenseTotal,
              currencyCode: settings.currencyCode,
              onTap: () => _openCapture(context),
            ),
            const SizedBox(height: 12),
          ],
          if (missingCheck.shouldAsk) ...[
            _MissingExpenseBanner(
              onTap: () => _openMissingExpense(context, missingCheck),
              onDismiss: () => settings.dismissMissingExpense(DateTime.now()),
            ),
            const SizedBox(height: 12),
          ],
          _BalanceCard(
            key: overviewAnchor,
            balance: balance,
            income: totals.income,
            expense: totals.expense,
            settings: settings,
          ),
          const SizedBox(height: 12),
          _MoneyMapStrip(
            plan: plan,
            currencyCode: settings.currencyCode,
            onTap: () => _openMoneyMap(context),
          ),
          const SizedBox(height: 12),
          _DailyBudgetCard(
            key: allowanceAnchor,
            snapshot: snapshot,
            currencyCode: settings.currencyCode,
            onSetBudget: onOpenSettings,
            onOpenReports: () => _openReports(context),
          ),
          if (snapshot.hasBudget) ...[
            const SizedBox(height: 12),
            _BudgetBar(
              spent: totals.expense,
              budget: settings.monthlyBudget,
              reserved: upcoming.reservedForMonth(month),
              currencyCode: settings.currencyCode,
            ),
          ],
          if ((settings.recoveryActive && !settings.recoveryFinished(now)) ||
              (snapshot.hasBudget &&
                  (snapshot.monthlyLeft < 0 ||
                      snapshot.remainingToday < 0))) ...[
            const SizedBox(height: 12),
            _RecoveryNudge(
              settings: settings,
              snapshot: snapshot,
              currencyCode: settings.currencyCode,
              onTap: () => _openRecovery(context),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.trendingUp,
                  label: 'Income',
                  value: totals.income,
                  color: AppColors.income,
                  currencyCode: settings.currencyCode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.trendingDown,
                  label: 'Expense',
                  value: totals.expense,
                  color: AppColors.expense,
                  currencyCode: settings.currencyCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ToolsStrip(
            studentMode: settings.studentMode,
            onWhatIf: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WhatIfScreen()),
            ),
            onPatterns: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PatternsScreen()),
            ),
            onShared: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SharedScreen()),
            ),
            onExpected: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExpectedIncomeScreen()),
            ),
            onStudent: settings.studentMode
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StudentScreen()),
                    )
                : null,
          ),
          const SizedBox(height: 24),
          _GoalsSection(
            goals: goals.all.take(2).toList(),
            totalSaved: goals.totalSaved,
            totalTarget: goals.totalTarget,
            currencyCode: settings.currencyCode,
            onSeeAll: () => _openGoals(context),
            onAdd: () => _openGoalSheet(context),
            onTapGoal: (goal) => _openGoalSheet(context, existing: goal),
          ),
          const SizedBox(height: 24),
          _UpcomingSection(
            items: nextBills,
            reserved: upcoming.reservedForMonth(month),
            currencyCode: settings.currencyCode,
            onSeeAll: () => _openUpcoming(context),
            onAdd: () => _openUpcomingSheet(context),
            onTapItem: (item) => _openUpcomingSheet(context, existing: item),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent activity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    color: scheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: txs.isEmpty ? null : onSeeAll,
                icon: const Icon(LucideIcons.arrowRight, size: 15),
                label: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (txs.recent().isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30, bottom: 40),
              child: emptyTransactions,
            )
          else
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    for (final tx in txs.recent())
                      TransactionTile(tx: tx, settings: settings),
                  ],
                ),
              ),
            ),
          const DailyMoneyFooter(),
        ],
      ),
    );
  }

  void _openReports(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportsScreen(initialMonth: monthOf(DateTime.now())),
      ),
    );
  }

  void _openMoneyMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MoneyMapScreen()),
    );
  }

  void _openRecovery(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const RecoverySheet(),
    );
  }

  void _openMissingExpense(BuildContext context, MissingExpenseCheck check) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MissingExpenseSheet(check: check),
    );
  }

  void _openUpcoming(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UpcomingScreen()),
    );
  }

  void _openUpcomingSheet(BuildContext context, {UpcomingExpense? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => UpcomingSheet(existing: existing),
    );
  }

  void _openAssistant(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AssistantScreen()),
    );
  }

  void _openCapture(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
  }

  void _openGoals(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    );
  }

  void _openGoalSheet(BuildContext context, {SavingsGoal? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GoalSheet(existing: existing),
    );
  }
}

// ── Private building blocks ─────────────────────────────────────

class _DailyBudgetCard extends StatelessWidget {
  const _DailyBudgetCard({
    super.key,
    required this.snapshot,
    required this.currencyCode,
    required this.onSetBudget,
    required this.onOpenReports,
  });

  final DailyBudgetSnapshot snapshot;
  final String currencyCode;
  final VoidCallback onSetBudget;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!snapshot.hasBudget) {
      return Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onSetBudget,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    LucideIcons.circleDollarSign,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set your monthly budget',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'See how much you can spend each day and how much is left.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.outline,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.arrowRight, size: 18, color: scheme.outline),
              ],
            ),
          ),
        ),
      );
    }

    final over = snapshot.remainingToday < 0;
    final overMonth = snapshot.monthlyLeft < 0;
    final ratio = snapshot.spentRatio.clamp(0.0, 1.0).toDouble();
    final accent = over
        ? AppColors.expense
        : overMonth
            ? AppColors.warn
            : ratio >= 0.8
                ? AppColors.warn
                : scheme.primary;
    final display = over ? -snapshot.remainingToday : snapshot.remainingToday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.calendarDays, size: 17, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Today's spending money",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenReports,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                  ),
                  child: const Text(
                    'Report',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    fmtMoney(display, currencyCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    over ? 'over budget' : 'left today',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                valueColor: AlwaysStoppedAnimation(accent),
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${fmtMoney(snapshot.spentToday, currencyCode)} spent',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: scheme.outline),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${fmtMoney(snapshot.allowance, currencyCode)} allowance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 11.5, color: scheme.outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(context, 'Days left', '${snapshot.daysLeft}'),
                if (snapshot.monthlyLeft < 0)
                  _pill(
                    context,
                    'Month over',
                    fmtMoney(-snapshot.monthlyLeft, currencyCode),
                    valueColor: AppColors.expense,
                  )
                else
                  _pill(context, 'Month left',
                      fmtMoney(snapshot.monthlyLeft, currencyCode)),
                if (snapshot.reservedUpcoming > 0)
                  _pill(context, 'Bills set aside',
                      fmtMoney(snapshot.reservedUpcoming, currencyCode)),
                if (snapshot.rolledOver > 0)
                  _pill(context, 'Rolled over',
                      '+${fmtMoney(snapshot.rolledOver, currencyCode)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String caption, String value,
      {Color? valueColor}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.outlineVariant.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$caption ',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: scheme.outline,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: valueColor ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingExpenseBanner extends StatelessWidget {
  const _MissingExpenseBanner({
    required this.onTap,
    required this.onDismiss,
  });

  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: AppColors.warn.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.receiptText,
                  size: 19,
                  color: AppColors.warn,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anything missing today?',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      'Cash purchases may not be recorded yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Not today',
                onPressed: onDismiss,
                icon: Icon(
                  LucideIcons.x,
                  size: 18,
                  color: scheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyMapStrip extends StatelessWidget {
  const _MoneyMapStrip({
    required this.plan,
    required this.currencyCode,
    required this.onTap,
  });

  final MoneyPlan plan;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasBalance = plan.hasConfirmedBalance;
    final amount = hasBalance ? plan.safeToSpend : plan.availableToSpend;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.map,
                  size: 19,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Money map',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      hasBalance
                          ? '${fmtMoney(amount, currencyCode)} safe · '
                              '${fmtMoney(plan.protectedTotal, currencyCode)} '
                              'protected'
                          : 'Budget plan · record income to protect a balance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryNudge extends StatelessWidget {
  const _RecoveryNudge({
    required this.settings,
    required this.snapshot,
    required this.currencyCode,
    required this.onTap,
  });

  final SettingsProvider settings;
  final DailyBudgetSnapshot snapshot;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active =
        settings.recoveryActive && !settings.recoveryFinished(DateTime.now());
    final day = settings.recoveryDayNumber(DateTime.now());
    return Material(
      color: AppColors.warn.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              const Icon(
                LucideIcons.heartPulse,
                size: 19,
                color: AppColors.warn,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active
                          ? 'Recovery plan · day $day of '
                              '${settings.recoveryDays}'
                          : 'Over your plan? Recover gently',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      active
                          ? '${fmtMoney(settings.recoveryDailyCut, currencyCode)} '
                              'less per day · tap to manage'
                          : 'Spread the overspend over a short window without '
                              'touching savings',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolsStrip extends StatelessWidget {
  const _ToolsStrip({
    required this.studentMode,
    required this.onWhatIf,
    required this.onPatterns,
    required this.onShared,
    required this.onExpected,
    this.onStudent,
  });

  final bool studentMode;
  final VoidCallback onWhatIf;
  final VoidCallback onPatterns;
  final VoidCallback onShared;
  final VoidCallback onExpected;
  final VoidCallback? onStudent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tools',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: scheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ToolChip(
              icon: LucideIcons.gitBranch,
              label: 'What if?',
              onTap: onWhatIf,
            ),
            _ToolChip(
              icon: LucideIcons.scanSearch,
              label: 'Patterns',
              onTap: onPatterns,
            ),
            _ToolChip(
              icon: LucideIcons.users,
              label: 'Shared',
              onTap: onShared,
            ),
            _ToolChip(
              icon: LucideIcons.calendarClock,
              label: 'Expected',
              onTap: onExpected,
            ),
            if (studentMode && onStudent != null)
              _ToolChip(
                icon: LucideIcons.graduationCap,
                label: 'Student',
                onTap: onStudent!,
              ),
          ],
        ),
      ],
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureBanner extends StatelessWidget {
  const _CaptureBanner({
    required this.count,
    required this.total,
    required this.currencyCode,
    required this.onTap,
  });

  final int count;
  final double total;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: AppColors.warn.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.radar,
                  size: 20,
                  color: AppColors.warn,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count payment${count == 1 ? '' : 's'} to review',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      '${fmtMoney(total, currencyCode)} detected · '
                      'tap to review',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({
    required this.goals,
    required this.totalSaved,
    required this.totalTarget,
    required this.currencyCode,
    required this.onSeeAll,
    required this.onAdd,
    required this.onTapGoal,
  });

  final List<SavingsGoal> goals;
  final double totalSaved;
  final double totalTarget;
  final String currencyCode;
  final VoidCallback onSeeAll;
  final VoidCallback onAdd;
  final ValueChanged<SavingsGoal> onTapGoal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = totalTarget <= 0
        ? 0.0
        : (totalSaved / totalTarget).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Savings goals',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  color: scheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: goals.isEmpty ? onAdd : onSeeAll,
              icon: Icon(
                goals.isEmpty ? LucideIcons.plus : LucideIcons.arrowRight,
                size: 15,
              ),
              label: Text(goals.isEmpty ? 'Create' : 'See all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (goals.isEmpty)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onAdd,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.target,
                        size: 18,
                        color: AppColors.income,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Give your savings a target',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            'Emergency fund, a trip or your next big buy',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.plus, size: 18, color: scheme.primary),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onSeeAll,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            fmtMoney(totalSaved, currencyCode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Text(
                          'of ${fmtMoney(totalTarget, currencyCode)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.income),
                        backgroundColor:
                            scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final goal in goals) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onTapGoal(goal),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Icon(
                                goal.isComplete
                                    ? LucideIcons.check
                                    : LucideIcons.piggyBank,
                                size: 16,
                                color: goal.isComplete
                                    ? AppColors.income
                                    : scheme.primary,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  goal.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                '${(goal.progress * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: goal.isComplete
                                      ? AppColors.income
                                      : scheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({
    required this.items,
    required this.reserved,
    required this.currencyCode,
    required this.onSeeAll,
    required this.onAdd,
    required this.onTapItem,
  });

  final List<UpcomingExpense> items;
  final double reserved;
  final String currencyCode;
  final VoidCallback onSeeAll;
  final VoidCallback onAdd;
  final ValueChanged<UpcomingExpense> onTapItem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Upcoming bills',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  color: scheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onSeeAll,
              icon: const Icon(LucideIcons.arrowRight, size: 15),
              label: Text(items.isEmpty ? 'Manage' : 'See all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onAdd,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.warn.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.calendarClock,
                        size: 18,
                        color: AppColors.warn,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No bills tracked yet',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            'Set aside rent, utilities or subscriptions',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.plus, size: 18, color: scheme.primary),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  for (final item in items)
                    UpcomingTile(
                      item: item,
                      currencyCode: currencyCode,
                      onTap: () => onTapItem(item),
                    ),
                ],
              ),
            ),
          ),
        if (reserved > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                Icon(LucideIcons.circleAlert, size: 13, color: scheme.outline),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${fmtMoney(reserved, currencyCode)} kept aside from this '
                    "month's budget",
                    style: TextStyle(fontSize: 11.5, color: scheme.outline),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
    required this.settings,
  });

  static const Color gradientTop = Color(0xFF12B98A);
  static const Color gradientBottom = Color(0xFF0B7A61);

  final double balance;
  final double income;
  final double expense;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientTop, gradientBottom],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradientBottom.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Total balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  monthName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            fmtMoney(balance, settings.currencyCode),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _pill(
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFFB9F5DD),
                label: fmtMoney(income, settings.currencyCode),
                caption: 'In',
              ),
              const SizedBox(width: 10),
              _pill(
                icon: Icons.arrow_upward_rounded,
                color: const Color(0xFFFFD9D4),
                label: fmtMoney(expense, settings.currencyCode),
                caption: 'Out',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required Color color,
    required String label,
    required String caption,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: gradientBottom),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({
    required this.spent,
    required this.budget,
    required this.reserved,
    required this.currencyCode,
  });

  final double spent;
  final double budget;
  final double reserved;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Count reserved bills as committed budget: the money is not spendable,
    // even though it is not an expense yet.
    final committed = spent + reserved;
    final ratio = (committed / budget).clamp(0.0, 1.6).toDouble();
    final pct = ratio * 100;
    final barColor = ratio >= 1
        ? AppColors.expense
        : ratio >= 0.8
            ? AppColors.warn
            : scheme.primary;
    final left = budget - committed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Monthly budget',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${fmtMoney(spent, currencyCode)} / ${fmtMoney(budget, currencyCode)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12.5, color: scheme.outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1).toDouble(),
                minHeight: 9,
                valueColor: AlwaysStoppedAnimation(barColor),
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              pct >= 100
                  ? 'Budget exceeded by ${fmtMoney(-left, currencyCode)}'
                  : '${fmtMoney(left, currencyCode)} left · ${pct.round()}% committed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: barColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.currencyCode,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color color;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This month · $label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.outline,
                    ),
                  ),
                  Text(
                    fmtMoney(value, currencyCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
