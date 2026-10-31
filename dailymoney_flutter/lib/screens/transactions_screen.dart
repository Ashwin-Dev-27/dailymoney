import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/tx.dart';
import '../providers/settings_provider.dart';
import '../providers/shared_provider.dart';
import '../providers/transactions_provider.dart';
import '../theme.dart';
import '../widgets/daily_money_footer.dart';

import '../utils/format.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/empty_state.dart';
import 'add_edit_sheet.dart';
import '../services/sound_service.dart';

/// Full transaction history: search, type filter and month navigation.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _query = '';
  TxType? _type; // null = all
  DateTime _month = monthOf(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final txs = context.watch<TransactionsProvider>();
    final list = txs.filtered(query: _query, type: _type, month: _month);
    final atCurrent = sameMonth(_month, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions', style: TextStyle(color: scheme.onSurface)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search title or note',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Type filter — horizontal scroll keeps all options reachable on
          // narrow phones instead of clipping the row.
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _filterChip(context, 'All', _type == null,
                    () => setState(() => _type = null)),
                const SizedBox(width: 8),
                _filterChip(
                    context,
                    'Income',
                    _type == TxType.income,
                    () => setState(() =>
                        _type = _type == TxType.income ? null : TxType.income),
                    color: AppColors.income),
                const SizedBox(width: 8),
                _filterChip(
                    context,
                    'Expense',
                    _type == TxType.expense,
                    () => setState(() => _type =
                        _type == TxType.expense ? null : TxType.expense),
                    color: AppColors.expense),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Month navigation sits on its own row so it is never clipped.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _monthButton(
                  icon: LucideIcons.chevronLeft,
                  onPressed: () =>
                      setState(() => _month = monthAdd(_month, -1)),
                ),
                Text(
                  atCurrent
                      ? 'This month'
                      : DateFormat('MMM yy').format(_month),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                _monthButton(
                  icon: LucideIcons.chevronRight,
                  onPressed: atCurrent
                      ? null
                      : () => setState(() => _month = monthAdd(_month, 1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: LucideIcons.receipt,
                    title: _query.isEmpty ? 'No transactions' : 'No matches',
                    message: _query.isEmpty
                        ? 'Nothing recorded for this filter combination.'
                        : 'Try a different search term or filter.',
                  )
                : _buildGroupedList(list, settings),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap, {
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: selected
          ? Icon(LucideIcons.check, size: 14, color: color ?? scheme.primary)
          : null,
      side: BorderSide(
        color: selected
            ? (color ?? scheme.primary).withValues(alpha: 0.55)
            : scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _monthButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }

  Widget _buildGroupedList(List<Tx> list, SettingsProvider settings) {
    final groups = <String, List<Tx>>{};
    for (final t in list) {
      groups.putIfAbsent(dayLabel(t.date), () => []).add(t);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: groups.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == groups.length) {
          return const DailyMoneyFooter();
        }
        final day = groups.keys.elementAt(i);
        final items = groups[day]!;
        var dayIncome = 0.0;
        var dayExpense = 0.0;
        for (final t in items) {
          if (t.type.isIncome) {
            dayIncome += t.statAmount;
          } else {
            dayExpense += t.statAmount;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  day,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.outline,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(
                    color: Theme.of(context)
                        .dividerTheme
                        .color
                        ?.withValues(alpha: 0.5),
                  ),
                ),
                if (dayIncome > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '+${fmtMoney(dayIncome, settings.currencyCode)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.income,
                    ),
                  ),
                ],
                if (dayExpense > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '-${fmtMoney(dayExpense, settings.currencyCode)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    for (final tx in items)
                      TransactionTile(
                        tx: tx,
                        settings: settings,
                        onTap: () => _openEdit(context, tx),
                        onLongPress: () => _confirmDelete(context, tx),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openEdit(BuildContext context, Tx tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddEditSheet(existing: tx),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Tx tx) async {
    final shared = context.read<SharedProvider>();
    final txs = context.read<TransactionsProvider>();
    final currency = context.read<SettingsProvider>().currencyCode;
    final split = shared.byLinkedTx(tx.id);
    final settlements = split == null
        ? const <Tx>[]
        : txs.all.where((t) => t.settlementOf == split.id).toList();
    final settledTotal =
        settlements.fold(0.0, (sum, settlement) => sum + settlement.amount);
    final detail = split != null
        ? (settlements.isNotEmpty
            ? '\n\nThis also removes '
                '${settlements.length == 1 ? 'the repayment' : '${settlements.length} repayments'} '
                'recorded for this split (${fmtMoney(settledTotal, currency)}). '
                'The shared record and its settled history are removed too.'
            : '\n\nThe linked shared record will be removed too.')
        : tx.settlementOf != null
            ? '\n\nThis also reverses the settlement on the shared record.'
            : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction'),
        content: Text('Delete "${tx.title}"? This cannot be undone.$detail'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      SoundService.instance.delete();
      await txs.remove(tx.id);
      await shared.removeForTransaction(tx, txs);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      }
    }
  }
}
