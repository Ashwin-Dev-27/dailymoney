import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/tx.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/money_plan.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/plan_widgets.dart';
import 'add_edit_sheet.dart';
import 'expected_income_screen.dart';
import 'shared_screen.dart';

/// A smaller, weekly-first view for allowances, hostel life and shared bills.
class StudentScreen extends StatelessWidget {
  const StudentScreen({super.key});

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
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final totals = txs.totalsFor(month);
    final weekLeft =
        snapshot.hasBudget ? snapshot.monthlyLeft / snapshot.daysLeft * 7 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student mode',
          style: TextStyle(color: scheme.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          if (!settings.studentMode) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            LucideIcons.graduationCap,
                            size: 19,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Built for allowances',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Student mode turns the plan weekly, adds pocket money, '
                      'scholarships, hostel and study categories, and keeps '
                      'shared bills visible. It changes wording and shortcuts '
                      '— never the maths.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: scheme.outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => settings.setStudentMode(true),
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: const Text('Turn on student mode'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Left this month',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    snapshot.hasBudget
                        ? fmtMoney(snapshot.monthlyLeft, currency)
                        : 'No allowance set',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: snapshot.hasBudget && snapshot.monthlyLeft < 0
                          ? AppColors.expense
                          : scheme.onSurface,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    snapshot.hasBudget
                        ? (weekLeft < 0
                            ? '${fmtMoney(-weekLeft, currency)} over budget '
                                'per week at this pace'
                            : 'About ${fmtMoney(weekLeft, currency)} a week for '
                                'the rest of this month')
                        : 'Set a monthly allowance to get a daily and weekly '
                            'number.',
                    style: TextStyle(fontSize: 11.5, color: scheme.outline),
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: PlanRow(
                          label: 'Money in',
                          value: fmtMoney(totals.income, currency),
                          color: AppColors.income,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PlanRow(
                          label: 'Spent',
                          value: fmtMoney(totals.expense, currency),
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!snapshot.hasBudget)
            FilledButton.icon(
              onPressed: () => _setAllowance(context, settings, currency),
              icon: const Icon(LucideIcons.wallet, size: 18),
              label: const Text('Set a monthly allowance'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => _setAllowance(context, settings, currency),
              icon: const Icon(LucideIcons.pencil, size: 17),
              label: const Text('Change monthly allowance'),
            ),
          const SizedBox(height: 20),
          const PlanSectionTitle(
            title: 'Quick record',
            subtitle: 'Only your own share enters spending totals.',
          ),
          Card(
            child: Column(
              children: [
                PlanToolTile(
                  icon: LucideIcons.wallet,
                  title: 'Pocket money received',
                  subtitle: 'Record income from family or an allowance',
                  onTap: () => _open(
                    context,
                    type: TxType.income,
                    categoryId: 'pocket-money',
                  ),
                ),
                const Divider(height: 1, indent: 60),
                PlanToolTile(
                  icon: LucideIcons.home,
                  title: 'Hostel or mess payment',
                  subtitle: 'Housing and food paid in one go',
                  onTap: () => _open(
                    context,
                    type: TxType.expense,
                    categoryId: 'hostel',
                  ),
                ),
                const Divider(height: 1, indent: 60),
                PlanToolTile(
                  icon: LucideIcons.bookOpen,
                  title: 'Books and study',
                  subtitle: 'Course fees, books or supplies',
                  onTap: () => _open(
                    context,
                    type: TxType.expense,
                    categoryId: 'study',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const PlanSectionTitle(
            title: 'Keep track',
            subtitle: 'The things that are easy to lose track of.',
          ),
          Card(
            child: Column(
              children: [
                PlanToolTile(
                  icon: LucideIcons.calendarClock,
                  title: 'Money still coming',
                  subtitle: 'Scholarship or family transfer, not counted yet',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ExpectedIncomeScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 60),
                PlanToolTile(
                  icon: LucideIcons.users,
                  title: 'Shared with friends',
                  subtitle: 'Split bills, track who owes whom',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SharedScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const PlanNote(
            icon: LucideIcons.info,
            text: 'Money owed to you is never counted as cash, and expected '
                'income stays outside your balance until you mark it received.',
          ),
        ],
      ),
    );
  }

  void _open(
    BuildContext context, {
    required TxType type,
    required String categoryId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddEditSheet(
        prefillType: type,
        prefillCategoryId: categoryId,
      ),
    );
  }

  Future<void> _setAllowance(
    BuildContext context,
    SettingsProvider settings,
    String currency,
  ) async {
    final value = await showAmountDialog(
      context,
      title: 'Monthly allowance',
      label: 'Allowance',
      currencyCode: currency,
      initial: settings.monthlyBudget,
      helper: 'The total you can spend this month.',
    );
    if (value == null || !context.mounted) return;
    await settings.setMonthlyBudget(value);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Allowance set to ${fmtMoney(value, currency)} for this month',
        ),
      ),
    );
  }
}
