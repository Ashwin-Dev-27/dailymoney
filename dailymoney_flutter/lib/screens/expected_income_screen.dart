import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/expected_income.dart';
import '../providers/expected_income_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/plan_widgets.dart';
import 'expected_income_sheet.dart';

/// Money the user expects to receive, kept apart from confirmed income.
class ExpectedIncomeScreen extends StatelessWidget {
  const ExpectedIncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final expected = context.watch<ExpectedIncomeProvider>();
    final currency = settings.currencyCode;
    final pending = expected.pending;
    final received = expected.received;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Expected income',
          style: TextStyle(color: scheme.onSurface),
        ),
        actions: [
          IconButton(
            tooltip: 'Add expected income',
            onPressed: () => _openSheet(context),
            icon: const Icon(LucideIcons.plus, size: 22),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expected, not received',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmtMoney(expected.pendingTotal, currency),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pending.isEmpty
                        ? 'Nothing waiting for confirmation'
                        : '${pending.length} payment'
                            '${pending.length == 1 ? '' : 's'} not counted yet',
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                  if (expected.nextPending != null) ...[
                    const Divider(height: 18),
                    Row(
                      children: [
                        Icon(LucideIcons.calendarClock,
                            size: 15, color: scheme.primary),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${expected.nextPending!.title} · '
                            '${dueLabel(expected.nextPending!.expectedDate)}',
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
                          fmtMoney(
                            expected.nextPending!.amount,
                            currency,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const PlanNote(
            icon: LucideIcons.info,
            text: 'Expected money never changes your balance, allowance or '
                'income totals. Only "Mark received" records real income.',
          ),
          const SizedBox(height: 18),
          if (expected.isEmpty) ...[
            const SizedBox(height: 20),
            const EmptyState(
              icon: LucideIcons.calendarClock,
              title: 'No expected income',
              message: 'Add money you are waiting for, so a delay never '
                  'quietly breaks your plan.',
            ),
            const SizedBox(height: 18),
            Center(
              child: FilledButton.icon(
                onPressed: () => _openSheet(context),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Add expected income'),
              ),
            ),
          ] else ...[
            if (pending.isNotEmpty) ...[
              const PlanSectionTitle(
                title: 'Waiting',
                subtitle: 'Nothing here is part of your spendable money.',
              ),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < pending.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      _ExpectedTile(
                        item: pending[i],
                        currency: currency,
                        onTap: () => _openSheet(context, existing: pending[i]),
                        onReceived: () => _markReceived(context, pending[i]),
                        onDelete: () => _confirmDelete(context, pending[i]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (received.isNotEmpty) ...[
              const PlanSectionTitle(
                title: 'Received',
                subtitle: 'These now appear as real income transactions.',
              ),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < received.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      _ReceivedTile(
                        item: received[i],
                        currency: currency,
                        onDelete: () => _confirmDelete(context, received[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, {ExpectedIncome? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExpectedIncomeSheet(existing: existing),
    );
  }

  Future<void> _markReceived(
    BuildContext context,
    ExpectedIncome item,
  ) async {
    final settings = context.read<SettingsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as received?'),
        content: Text(
          'Record ${fmtMoney(item.amount, settings.currencyCode)} as income '
          'now, dated today? This is the only step that adds expected money '
          'to your balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark received'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<ExpectedIncomeProvider>();
    final txs = context.read<TransactionsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final tx = await provider.markReceived(item, txs);
    if (tx == null || !context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${fmtMoney(tx.amount, settings.currencyCode)} recorded as income',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExpectedIncome item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove expected income?'),
        content: Text(
          'Remove "${item.title}"? Any income transaction already recorded '
          'when it was marked received is untouched.',
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
    await context.read<ExpectedIncomeProvider>().remove(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expected income removed')),
    );
  }
}

class _ExpectedTile extends StatelessWidget {
  const _ExpectedTile({
    required this.item,
    required this.currency,
    required this.onTap,
    required this.onReceived,
    required this.onDelete,
  });

  final ExpectedIncome item;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onReceived;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = item.isOverdue(DateTime.now());
    final lateDays = item.daysLate(DateTime.now());
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (overdue ? AppColors.warn : scheme.primary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.calendarClock,
                size: 19,
                color: overdue ? AppColors.warn : scheme.primary,
              ),
            ),
            const SizedBox(width: 11),
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
                  const SizedBox(height: 2),
                  Text(
                    overdue
                        ? '$lateDays ${lateDays == 1 ? 'day' : 'days'} late · '
                            '${item.confidence.label} confidence'
                        : '${dueLabel(item.expectedDate)} · '
                            '${item.confidence.label} confidence',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: overdue ? AppColors.warn : scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              fmtMoney(item.amount, currency),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: overdue ? AppColors.warn : scheme.onSurface,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (value) {
                if (value == 'received') onReceived();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'received',
                  child: Text('Mark received'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceivedTile extends StatelessWidget {
  const _ReceivedTile({
    required this.item,
    required this.currency,
    required this.onDelete,
  });

  final ExpectedIncome item;
  final String currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              LucideIcons.badgeCheck,
              size: 18,
              color: AppColors.income,
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  item.receivedDate == null
                      ? 'Received'
                      : 'Received ${dayLabel(item.receivedDate!)}',
                  style: TextStyle(fontSize: 11.5, color: scheme.outline),
                ),
              ],
            ),
          ),
          Text(
            '+${fmtMoney(item.amount, currency)}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.income,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (_) => onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Remove record')),
            ],
          ),
        ],
      ),
    );
  }
}
