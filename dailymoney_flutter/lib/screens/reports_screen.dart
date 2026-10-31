import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/daily_budget.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Monthly budget performance plus a day-by-day spending report.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = monthOf(widget.initialMonth ?? DateTime.now());
  }

  bool get _atCurrentMonth => sameMonth(_month, DateTime.now());

  void _shift(int delta) => setState(() => _month = monthAdd(_month, delta));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final txs = context.watch<TransactionsProvider>();
    final upcoming = context.watch<UpcomingProvider>();
    final now = DateTime.now();
    final isPast = _month.isBefore(monthOf(now));

    final rows = DailyBudget.reportRows(
      settings: settings,
      transactions: txs.all,
      upcoming: upcoming,
      month: _month,
      today: now,
    );
    final income = rows.fold(0.0, (a, r) => a + r.income);
    final expense = rows.fold(0.0, (a, r) => a + r.expense);
    final reserved = isPast ? 0.0 : upcoming.reservedForMonth(_month);
    final budget = settings.monthlyBudget;
    final hasBudget = budget > 0;
    final monthlyLeft = budget - expense - reserved;
    final daysTracked = rows.where((r) => r.hadExpense).length;
    final overDays = rows.where((r) => r.hadExpense && r.isOver).length;
    final underDays = hasBudget
        ? rows.where((r) => r.hadExpense && r.allowance > 0 && !r.isOver).length
        : 0;
    final unspent = hasBudget
        ? rows.fold(0.0, (a, r) => a + math.max(0.0, r.remaining))
        : 0.0;
    final avgDaily = rows.isEmpty ? 0.0 : expense / rows.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Reports', style: TextStyle(color: scheme.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          Row(
            children: [
              _roundBtn(
                icon: LucideIcons.chevronLeft,
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthLabel(_month),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              _roundBtn(
                icon: LucideIcons.chevronRight,
                onPressed: _atCurrentMonth ? null : () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PerformanceCard(
            hasBudget: hasBudget,
            budget: budget,
            expense: expense,
            reserved: reserved,
            monthlyLeft: monthlyLeft,
            avgDaily: avgDaily,
            currencyCode: settings.currencyCode,
            carryForward: settings.carryForward,
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  _totalsCell(
                    context,
                    'Income',
                    fmtMoney(income, settings.currencyCode),
                    AppColors.income,
                  ),
                  _totalsCell(
                    context,
                    'Expense',
                    fmtMoney(expense, settings.currencyCode),
                    AppColors.expense,
                  ),
                  _totalsCell(
                    context,
                    'Spent days',
                    '$daysTracked',
                    const Color(0xFF6366F1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily breakdown',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    color: scheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (hasBudget)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    '$overDays over · $underDays under',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.outline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasBudget)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 66,
                    child: Text(
                      'Day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Spent',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.outline,
                      ),
                    ),
                  ),
                  Text(
                    'Left vs allowance',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    _dayRow(context, rows[i], hasBudget, settings.currencyCode),
                    if (i < rows.length - 1)
                      Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (hasBudget) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '${fmtMoney(unspent, settings.currencyCode)} of allowance went '
                'unspent on the days above. Carry-forward is '
                '${settings.carryForward ? 'on, so it is added to later days' : 'off, so each day starts fresh'}.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.outline,
                  height: 1.5,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Add a monthly budget in Settings to compare each day against '
                'a spending allowance.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.outline,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dayRow(
    BuildContext context,
    DailyReportRow row,
    bool hasBudget,
    String currencyCode,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final over = row.isOver;
    final remainingColor = !hasBudget
        ? scheme.outline
        : over
            ? AppColors.expense
            : AppColors.income;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 66,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.date.day} ${weekdayLabel(row.date)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                if (row.income > 0)
                  Text(
                    '+${fmtMoney(row.income, currencyCode)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.income,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              row.expense > 0 ? '-${fmtMoney(row.expense, currencyCode)}' : '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: row.expense > 0 ? FontWeight.w700 : FontWeight.w500,
                color: row.expense > 0 ? AppColors.expense : scheme.outline,
              ),
            ),
          ),
          Flexible(
            child: Text(
              !hasBudget
                  ? '—'
                  : over
                      ? '${fmtMoney(-row.remaining, currencyCode)} over'
                      : '${fmtMoney(row.remaining, currencyCode)} left',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: remainingColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsCell(
    BuildContext context,
    String caption,
    String value,
    Color color,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn({required IconData icon, required VoidCallback? onPressed}) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: scheme.outlineVariant.withValues(alpha: 0.25),
        foregroundColor: scheme.onSurface,
        disabledForegroundColor: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.hasBudget,
    required this.budget,
    required this.expense,
    required this.reserved,
    required this.monthlyLeft,
    required this.avgDaily,
    required this.currencyCode,
    required this.carryForward,
  });

  final bool hasBudget;
  final double budget;
  final double expense;
  final double reserved;
  final double monthlyLeft;
  final double avgDaily;
  final String currencyCode;
  final bool carryForward;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Reserved bills are committed budget too, so the progress bar includes
    // them; the big number above still shows actual spending.
    final ratio = hasBudget ? (expense + reserved) / budget : 0.0;
    final barValue = ratio.clamp(0.0, 1.0).toDouble();
    final over = hasBudget && monthlyLeft < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.chartColumn, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Month performance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (hasBudget) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${(ratio * 100).round()}% committed',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (!hasBudget)
              Text(
                'No monthly budget set. Recorded spending is still shown below.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.outline,
                  height: 1.5,
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: fmtMoney(expense, currencyCode),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${fmtMoney(budget, currencyCode)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.outline,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: (over ? AppColors.expense : AppColors.income)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      over
                          ? '${fmtMoney(-monthlyLeft, currencyCode)} over'
                          : '${fmtMoney(monthlyLeft, currencyCode)} left',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: over ? AppColors.expense : AppColors.income,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: barValue,
                  minHeight: 8,
                  valueColor: AlwaysStoppedAnimation(
                    ratio >= 1
                        ? AppColors.expense
                        : ratio >= 0.8
                            ? AppColors.warn
                            : scheme.primary,
                  ),
                  backgroundColor:
                      scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metric(
                    context,
                    'Reserved bills',
                    fmtMoney(reserved, currencyCode),
                  ),
                  _metric(
                    context,
                    'Avg / day',
                    fmtMoney(avgDaily, currencyCode),
                  ),
                  _metric(
                    context,
                    'Carry-forward',
                    carryForward ? 'On' : 'Off',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String caption, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
