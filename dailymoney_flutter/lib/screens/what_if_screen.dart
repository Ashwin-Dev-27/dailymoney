import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/money_plan.dart';
import '../services/what_if.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/plan_widgets.dart';
import 'goal_sheet.dart';
import 'goals_screen.dart';
import 'expected_income_screen.dart';
import 'purchase_assistant_screen.dart';
import 'upcoming_screen.dart';

/// Deterministic "what happens if…" scenarios.
class WhatIfScreen extends StatefulWidget {
  const WhatIfScreen({super.key});

  @override
  State<WhatIfScreen> createState() => _WhatIfScreenState();
}

class _WhatIfScreenState extends State<WhatIfScreen> {
  final _amount = TextEditingController(text: '500');
  WhatIfKind _kind = WhatIfKind.purchase;
  int _delayDays = 7;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value {
    final parsed = parseAmount(_amount.text);
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final txs = context.watch<TransactionsProvider>();
    final upcoming = context.watch<UpcomingProvider>();
    final goals = context.watch<GoalsProvider>();
    final currency = settings.currencyCode;
    final now = DateTime.now();
    final plan = MoneyPlan.compute(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
      today: now,
    );
    final base = WhatIfEngine.baseline(snapshot: plan.snapshot, plan: plan);
    final amount = _kind == WhatIfKind.incomeDelay ? 0.0 : _value;
    final result = amount == null
        ? null
        : WhatIfEngine.simulate(
            kind: _kind,
            amount: amount,
            days: _delayDays,
            snapshot: plan.snapshot,
            plan: plan,
            upcoming: upcoming,
            now: now,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text('What if?', style: TextStyle(color: scheme.onSurface)),
        actions: [
          IconButton(
            tooltip: 'Can I buy it?',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PurchaseAssistantScreen(),
              ),
            ),
            icon: const Icon(LucideIcons.shoppingBag, size: 20),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          const PlanNote(
            icon: LucideIcons.flaskConical,
            text: 'These are simulations, not commitments. Nothing is added '
                'to your ledger, balance or bills unless you record it.',
          ),
          const SizedBox(height: 16),
          const PlanSectionTitle(
            title: 'Scenario',
            subtitle: 'Pick one change and see how it moves the plan.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in WhatIfKind.values)
                ChoiceChip(
                  label: Text(kind.label),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_kind != WhatIfKind.incomeDelay)
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _kind == WhatIfKind.weeklySaving
                    ? 'Amount each week'
                    : _kind == WhatIfKind.billIncrease
                        ? 'How much the bill rises'
                        : 'Purchase price',
                prefixText: '${currencyByCode(currency).symbol} ',
              ),
            ),
          if (_kind == WhatIfKind.incomeDelay) ...[
            const SizedBox(height: 12),
            Text(
              'Delay',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final days in [3, 7, 14, 30])
                  ChoiceChip(
                    label: Text('$days days'),
                    selected: _delayDays == days,
                    onSelected: (_) => setState(() => _delayDays = days),
                    showCheckmark: false,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (result == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(LucideIcons.pencil, size: 18, color: scheme.outline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enter an amount above zero to run the scenario.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _ResultCard(
              result: result,
              currency: currency,
              hasBudget: plan.snapshot.hasBudget,
            ),
            const SizedBox(height: 14),
            _ComparisonCard(
              baseline: base,
              result: result,
              currency: currency,
            ),
            if (result.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What this includes',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final note in result.notes)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 5, right: 7),
                                child: Icon(LucideIcons.dot, size: 10),
                              ),
                              Expanded(
                                child: Text(
                                  note,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: scheme.outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _nextStep(context),
          ],
        ],
      ),
    );
  }

  Widget _nextStep(BuildContext context) {
    return switch (_kind) {
      WhatIfKind.purchase => FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PurchaseAssistantScreen(),
            ),
          ),
          icon: const Icon(LucideIcons.shieldCheck, size: 18),
          label: const Text('Check one purchase properly'),
        ),
      WhatIfKind.incomeDelay => OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ExpectedIncomeScreen(),
            ),
          ),
          icon: const Icon(LucideIcons.calendarClock, size: 18),
          label: const Text('Track expected income'),
        ),
      WhatIfKind.billIncrease => OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UpcomingScreen()),
          ),
          icon: const Icon(LucideIcons.receipt, size: 18),
          label: const Text('Review upcoming bills'),
        ),
      WhatIfKind.weeklySaving => OutlinedButton.icon(
          onPressed: () => _createGoal(context),
          icon: const Icon(LucideIcons.target, size: 18),
          label: const Text('Turn this into a savings goal'),
        ),
    };
  }

  void _createGoal(BuildContext context) {
    final goals = context.read<GoalsProvider>();
    if (goals.isEmpty) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const GoalSheet(),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.currency,
    required this.hasBudget,
  });

  final WhatIfResult result;
  final String currency;
  final bool hasBudget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bad = result.availableAfter < -0.005;
    final tight = !bad && result.monthLeft < -0.005;
    final color = bad
        ? AppColors.expense
        : tight
            ? AppColors.warn
            : scheme.primary;
    final title = bad
        ? 'This would eat into protected money'
        : tight
            ? 'Possible, but it changes the rest of the month'
            : 'This fits the current plan';
    final detail = bad
        ? 'Confirmed money would fall ${fmtMoney(-result.availableAfter, currency)} '
            'short after bills, savings and your buffer.'
        : tight
            ? 'The monthly plan would go over by '
                '${fmtMoney(-result.monthLeft, currency)}.'
            : hasBudget
                ? 'It stays inside the money left after protected buckets.'
                : 'Set a budget to see how this affects a daily allowance.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.flaskConical, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Safe after',
                    value: fmtMoney(result.availableAfter, currency),
                    color: result.availableAfter < 0
                        ? AppColors.expense
                        : scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Metric(
                    label: 'Month after',
                    value: fmtMoney(result.monthLeft, currency),
                    color: result.monthLeft < 0
                        ? AppColors.warn
                        : scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Metric(
                    label: 'Per day after',
                    value: fmtMoney(result.dailyAllowance, currency),
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            if (result.goalDelayMonths > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Savings impact: about ${result.goalDelayMonths} '
                '${result.goalDelayMonths == 1 ? 'month' : 'months'} of your '
                'current goal commitment.',
                style: TextStyle(fontSize: 11.5, color: scheme.outline),
              ),
            ],
            if (result.billsShortfall > 0) ...[
              const SizedBox(height: 10),
              PlanNote(
                color: AppColors.expense,
                icon: LucideIcons.circleAlert,
                text: 'Bills due in this window would be '
                    '${fmtMoney(result.billsShortfall, currency)} short.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.baseline,
    required this.result,
    required this.currency,
  });

  final WhatIfResult baseline;
  final WhatIfResult result;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(
                  child: Text(
                    'Now',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scheme.outline,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Then',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            _row('Left today', baseline.todayLeft, result.todayLeft),
            _row('Daily allowance', baseline.dailyAllowance,
                result.dailyAllowance),
            _row('Month left', baseline.monthLeft, result.monthLeft),
            _row('Safe to spend', baseline.availableAfter,
                result.availableAfter),
            _row('Projected balance', baseline.projectedBalance,
                result.projectedBalance),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double now, double then) {
    final color = then < now - 0.005
        ? AppColors.expense
        : then > now + 0.005
            ? AppColors.income
            : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              fmtMoney(now, currency),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              fmtMoney(then, currency),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: scheme.outline),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: color ?? scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
