import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/shared_expense.dart';
import '../models/tx.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shared_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/budget_alerts.dart';
import '../services/money_plan.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/plan_widgets.dart';
import 'add_edit_sheet.dart';
import 'shared_expense_sheet.dart';

/// Receivables and payables from money shared with other people.
class SharedScreen extends StatelessWidget {
  const SharedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final shared = context.watch<SharedProvider>();
    final currency = settings.currencyCode;
    final receivables = shared.byDirection(SharedDirection.owedToMe);
    final payables = shared.byDirection(SharedDirection.iOwe);
    final openReceivables =
        receivables.where((e) => !e.isSettled).toList(growable: false);
    final openPayables =
        payables.where((e) => !e.isSettled).toList(growable: false);
    final settled =
        shared.all.where((e) => e.isSettled).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Shared expenses',
          style: TextStyle(color: scheme.onSurface),
        ),
        actions: [
          IconButton(
            tooltip: 'Track money owed',
            onPressed: () => _openSheet(context),
            icon: const Icon(LucideIcons.plus, size: 22),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          _SummaryCard(
            owedToMe: shared.owedToMe,
            iOwe: shared.iOwe,
            net: shared.net,
            currency: currency,
          ),
          const SizedBox(height: 10),
          const PlanNote(
            icon: LucideIcons.users,
            text: 'Only your own share counts as spending. A repayment you '
                'receive changes your balance but is never counted as income.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openAddExpense(context),
                  icon: const Icon(LucideIcons.receipt, size: 17),
                  label: const Text('Record a shared payment'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openSheet(context),
            icon: const Icon(LucideIcons.handCoins, size: 17),
            label: const Text('Track money owed separately'),
          ),
          const SizedBox(height: 20),
          if (shared.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 22),
              child: EmptyState(
                icon: LucideIcons.users,
                title: 'Nothing shared yet',
                message: 'Split a bill or track money you owe. Your own share '
                    'is what enters your spending totals.',
              ),
            )
          else ...[
            if (openReceivables.isNotEmpty) ...[
              PlanSectionTitle(
                title: 'Owed to you',
                subtitle: '${openReceivables.length} open · '
                    '${fmtMoney(shared.owedToMe, currency)} outstanding',
              ),
              for (final item in openReceivables)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _SharedTile(
                    item: item,
                    currency: currency,
                    onSettle: () => _settle(context, item),
                    onEdit: () => _openSheet(context, existing: item),
                    onDelete: () => _confirmDelete(context, item),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (openPayables.isNotEmpty) ...[
              PlanSectionTitle(
                title: 'You owe',
                subtitle: '${openPayables.length} open · '
                    '${fmtMoney(shared.iOwe, currency)} outstanding',
              ),
              for (final item in openPayables)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _SharedTile(
                    item: item,
                    currency: currency,
                    onSettle: () => _settle(context, item),
                    onEdit: () => _openSheet(context, existing: item),
                    onDelete: () => _confirmDelete(context, item),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (settled.isNotEmpty)
              Card(
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(LucideIcons.badgeCheck, size: 19),
                  title: Text('Settled (${settled.length})'),
                  children: [
                    for (final item in settled)
                      ListTile(
                        dense: true,
                        title: Text(item.title),
                        subtitle: Text(
                          item.counterparty.isEmpty
                              ? 'Settled in full'
                              : 'Settled with ${item.counterparty}',
                        ),
                        trailing: Text(
                          fmtMoney(item.total, currency),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.outline,
                          ),
                        ),
                        onTap: () => _openSheet(context, existing: item),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, {SharedExpense? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SharedExpenseSheet(existing: existing),
    );
  }

  void _openAddExpense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddEditSheet(
        prefillType: TxType.expense,
        prefillShared: true,
      ),
    );
  }

  Future<void> _settle(BuildContext context, SharedExpense item) async {
    final settings = context.read<SettingsProvider>();
    final currency = settings.currencyCode;
    final isReceipt = item.direction == SharedDirection.owedToMe;
    final controller = TextEditingController(
      text: fmtAmountInput(item.outstanding),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isReceipt ? 'Record a repayment' : 'Record a payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${currencyByCode(currency).symbol} ',
                helperText:
                    'Outstanding: ${fmtMoney(item.outstanding, currency)}',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isReceipt
                  ? 'This records a settlement: it raises your balance but '
                      'does not count as income.'
                  : 'This records a real expense, because your share was not '
                      'counted when the bill was paid.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: Theme.of(ctx).colorScheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = parseAmount(controller.text);
              if (parsed == null || parsed <= 0) return;
              if (parsed > item.outstanding + 0.005) return;
              Navigator.pop(ctx, parsed);
            },
            child: Text(isReceipt ? 'Record receipt' : 'Record payment'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !context.mounted) return;
    final provider = context.read<SharedProvider>();
    final txs = context.read<TransactionsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final goals = context.read<GoalsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final before = MoneyPlan.snapshotFor(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
    );
    final tx = await provider.settle(item, amount, txs);
    if (tx == null || !context.mounted) return;
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
      isExpense: tx.type.isExpense,
      currency: currency,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isReceipt
              ? '${fmtMoney(amount, currency)} received · settlement, not income'
              : '${fmtMoney(amount, currency)} paid · recorded as an expense',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SharedExpense item) async {
    final linked = item.linkedTxId != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove shared record?'),
        content: Text(
          linked
              ? 'Remove "${item.title}"? The linked transaction stays in your '
                  'ledger, and its full amount will count as your spending '
                  'because there is no longer a share to collect.'
              : 'Remove "${item.title}"? Money already settled is not reversed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final txs = context.read<TransactionsProvider>();
    final provider = context.read<SharedProvider>();
    final linkedId = item.linkedTxId;
    if (linkedId != null) {
      for (final tx in txs.all) {
        if (tx.id == linkedId) {
          await txs.update(tx.copyWith(clearPersonalShare: true));
          break;
        }
      }
    }
    await provider.remove(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shared record removed')),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.owedToMe,
    required this.iOwe,
    required this.net,
    required this.currency,
  });

  final double owedToMe;
  final double iOwe;
  final double net;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net position',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              fmtMoney(net, currency),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: net < 0 ? AppColors.expense : scheme.onSurface,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              net < 0
                  ? 'You owe more than you are owed.'
                  : net > 0
                      ? 'You are owed more than you owe.'
                      : 'You are square with everyone tracked.',
              style: TextStyle(fontSize: 11.5, color: scheme.outline),
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: PlanRow(
                    label: 'Owed to you',
                    value: fmtMoney(owedToMe, currency),
                    color: AppColors.income,
                    icon: LucideIcons.arrowDownLeft,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PlanRow(
                    label: 'You owe',
                    value: fmtMoney(iOwe, currency),
                    color: AppColors.expense,
                    icon: LucideIcons.arrowUpRight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedTile extends StatelessWidget {
  const _SharedTile({
    required this.item,
    required this.currency,
    required this.onSettle,
    required this.onEdit,
    required this.onDelete,
  });

  final SharedExpense item;
  final String currency;
  final VoidCallback onSettle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final receipt = item.direction == SharedDirection.owedToMe;
    final tint = receipt ? AppColors.income : AppColors.expense;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    receipt
                        ? LucideIcons.arrowDownLeft
                        : LucideIcons.arrowUpRight,
                    size: 18,
                    color: tint,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        [
                          if (item.counterparty.isNotEmpty) item.counterparty,
                          dayLabel(item.date),
                          if (item.total > item.myShare && receipt)
                            'Total ${fmtMoney(item.total, currency)}',
                          if (!receipt) 'Your share',
                        ].join(' · '),
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
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Remove')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.settled > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 5,
                  backgroundColor: scheme.outlineVariant.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation(tint),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${fmtMoney(item.settled, currency)} of '
                '${fmtMoney(item.owed, currency)} settled',
                style: TextStyle(fontSize: 10.5, color: scheme.outline),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${fmtMoney(item.outstanding, currency)} '
                    '${receipt ? 'owed to you' : 'you owe'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: tint,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onSettle,
                  icon: Icon(
                    receipt ? LucideIcons.download : LucideIcons.upload,
                    size: 15,
                  ),
                  label: Text(
                    receipt ? 'Got it back' : 'Paid them',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
