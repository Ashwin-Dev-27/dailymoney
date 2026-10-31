import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/upcoming_expense.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/budget_alerts.dart';
import '../services/money_plan.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/upcoming_tile.dart';
import 'upcoming_sheet.dart';

/// Full list of expected bills, with a mark-paid flow.
class UpcomingScreen extends StatelessWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final upcoming = context.watch<UpcomingProvider>();
    final items = upcoming.all;
    final reserved = upcoming.reservedForMonth(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Upcoming bills', style: TextStyle(color: scheme.onSurface)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSheet(context),
        tooltip: 'Add upcoming bill',
        child: const Icon(LucideIcons.plus, size: 26),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.calendarClock,
                        size: 44, color: scheme.outline),
                    const SizedBox(height: 14),
                    Text(
                      'No upcoming bills',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track rent, utilities or subscriptions so DailyMoney '
                      'keeps that money out of your daily allowance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.outline,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => _openSheet(context),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('Add a bill'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.warn.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            LucideIcons.calendarClock,
                            size: 19,
                            color: AppColors.warn,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Set aside this month',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.outline,
                                ),
                              ),
                              Text(
                                fmtMoney(reserved, settings.currencyCode),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${items.length} ${items.length == 1 ? 'bill' : 'bills'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      children: [
                        for (final item in items)
                          UpcomingTile(
                            item: item,
                            currencyCode: settings.currencyCode,
                            onTap: () => _openSheet(context, existing: item),
                            onMarkPaid: () => _confirmPay(context, item),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'Tap a bill to edit it. Use the check button when you pay '
                    'it — DailyMoney records the expense and moves recurring '
                    'bills to next month.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.outline,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _openSheet(BuildContext context, {UpcomingExpense? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => UpcomingSheet(existing: existing),
    );
  }

  Future<void> _confirmPay(BuildContext context, UpcomingExpense item) async {
    final settings = context.read<SettingsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final txs = context.read<TransactionsProvider>();
    final goals = context.read<GoalsProvider>();
    final currency = settings.currencyCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark bill paid?'),
        content: Text(
          'This records "${item.title}" as a ${fmtMoney(item.amount, currency)} '
          'expense today.${item.repeatMonthly ? ' It will move to next month.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final before = MoneyPlan.snapshotFor(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
    );
    await upcoming.markPaid(item, txs);
    if (!context.mounted) return;
    final after = MoneyPlan.snapshotFor(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
    );
    BudgetAlerts.maybeNotify(
      settings: settings,
      before: before,
      after: after,
      isExpense: true,
      currency: currency,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Paid ${fmtMoney(item.amount, currency)} · expense added',
        ),
      ),
    );
  }
}
