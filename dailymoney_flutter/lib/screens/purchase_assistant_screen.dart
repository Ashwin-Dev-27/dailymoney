import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/tx.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/money_plan.dart';
import '../services/what_if.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/plan_widgets.dart';
import 'add_edit_sheet.dart';

/// Checks one purchase against confirmed money and the monthly plan.
class PurchaseAssistantScreen extends StatefulWidget {
  const PurchaseAssistantScreen({super.key});

  @override
  State<PurchaseAssistantScreen> createState() =>
      _PurchaseAssistantScreenState();
}

class _PurchaseAssistantScreenState extends State<PurchaseAssistantScreen> {
  final _price = TextEditingController();
  final _title = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    _title.dispose();
    super.dispose();
  }

  double? get _value {
    final parsed = parseAmount(_price.text);
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
    final plan = MoneyPlan.compute(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
    );
    final price = _value;
    final verdict = price == null
        ? null
        : WhatIfEngine.assessPurchase(
            price: price,
            snapshot: plan.snapshot,
            plan: plan,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Can I buy it?',
          style: TextStyle(color: scheme.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          const PlanNote(
            icon: LucideIcons.shieldCheck,
            text: 'This is a planning check. It does not pay for anything, and '
                'it never treats expected income or money owed to you as cash.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _price,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Price',
              hintText: '0.00',
              prefixText: '${currencyByCode(currency).symbol} ',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'What is it? (optional)',
              hintText: 'Headphones, shoes, dinner…',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          if (verdict == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(LucideIcons.shoppingBag,
                        size: 18, color: scheme.outline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enter a price to see whether confirmed money covers '
                        'it and what it does to the rest of the month.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: scheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _VerdictCard(
              verdict: verdict,
              currency: currency,
              hasConfirmedBalance: plan.hasConfirmedBalance,
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'After buying',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PlanRow(
                      label: 'Left in today\'s allowance',
                      value: fmtMoney(verdict.afterToday, currency),
                      color: verdict.afterToday < 0
                          ? AppColors.expense
                          : scheme.onSurface,
                    ),
                    PlanRow(
                      label: 'Left after protected money',
                      value: fmtMoney(verdict.afterAvailable, currency),
                      color: verdict.afterAvailable < 0
                          ? AppColors.expense
                          : scheme.onSurface,
                    ),
                    PlanRow(
                      label: 'Left this month',
                      value: fmtMoney(verdict.afterMonth, currency),
                      color: verdict.afterMonth < 0
                          ? AppColors.warn
                          : scheme.onSurface,
                    ),
                    PlanRow(
                      label: 'Daily allowance for the rest of the month',
                      value: fmtMoney(verdict.dailyAfter, currency),
                    ),
                    if (verdict.waitDays > 0) ...[
                      const Divider(height: 14),
                      Text(
                        'At today\'s allowance you would need about '
                        '${verdict.waitDays} '
                        '${verdict.waitDays == 1 ? 'day' : 'days'} of untouched '
                        'allowance to cover it. That is a rough guide, not a '
                        'reservation.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (!plan.hasConfirmedBalance)
              const PlanNote(
                icon: LucideIcons.info,
                text: 'No confirmed income is recorded, so this check falls '
                    'back to your monthly budget. Record income to make the '
                    'balance test exact.',
              ),
            if (!plan.hasConfirmedBalance) const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _record(context, price!, currency),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Record this purchase'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _startOver(),
              icon: const Icon(LucideIcons.rotateCcw, size: 17),
              label: const Text('Check another price'),
            ),
          ],
        ],
      ),
    );
  }

  void _startOver() {
    _price.clear();
    _title.clear();
    setState(() {});
  }

  void _record(BuildContext context, double price, String currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddEditSheet(
        prefillTitle: _title.text.trim(),
        prefillAmount: price,
        prefillType: TxType.expense,
      ),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({
    required this.verdict,
    required this.currency,
    required this.hasConfirmedBalance,
  });

  final PurchaseVerdict verdict;
  final String currency;
  final bool hasConfirmedBalance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (verdict.status) {
      Affordability.fitsToday => AppColors.income,
      Affordability.fitsMonth => scheme.primary,
      Affordability.tight => AppColors.warn,
      Affordability.notCovered => AppColors.expense,
    };
    final icon = switch (verdict.status) {
      Affordability.fitsToday => LucideIcons.badgeCheck,
      Affordability.fitsMonth => LucideIcons.calendarCheck,
      Affordability.tight => LucideIcons.alertTriangle,
      Affordability.notCovered => LucideIcons.circleAlert,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              verdict.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              verdict.detail,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: scheme.outline,
              ),
            ),
            if (!hasConfirmedBalance && verdict.isSafe) ...[
              const SizedBox(height: 6),
              Text(
                'This verdict uses the monthly budget because no confirmed '
                'balance is recorded.',
                style: TextStyle(fontSize: 11.5, color: scheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
