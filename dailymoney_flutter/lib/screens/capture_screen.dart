import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/detection.dart';
import '../models/tx.dart';
import '../providers/capture_provider.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/budget_alerts.dart';
import '../services/capture_service.dart';
import '../services/money_plan.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';

/// Review queue for payments detected in notification banners.
class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final capture = context.watch<CaptureProvider>();
    final settings = context.watch<SettingsProvider>();
    final txs = context.watch<TransactionsProvider>();
    final currency = settings.currencyCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detected payments',
          style: TextStyle(color: scheme.onSurface),
        ),
        actions: [
          if (capture.count > 1)
            TextButton(
              onPressed: () => _acceptAll(context, capture, txs),
              child: const Text('Accept all'),
            ),
        ],
      ),
      body: Column(
        children: [
          _AccessBanner(autoCapture: settings.autoCapture),
          Expanded(
            child: capture.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: EmptyState(
                      icon: LucideIcons.radar,
                      title: 'Nothing to review',
                      message:
                          'When a payment app posts a notification, the amount '
                          'will appear here for you to confirm before it is '
                          'added to your ledger.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Text(
                        '${capture.count} waiting · '
                        '${fmtMoney(capture.pendingExpenseTotal, currency)} in '
                        'expenses',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.outline,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final detection in capture.all) ...[
                        _DetectionCard(
                          detection: detection,
                          currencyCode: currency,
                          onAccept: () => _accept(context, detection),
                          onIgnore: () => capture.ignore(detection.id),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(LucideIcons.info,
                              size: 13, color: scheme.outline),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Only payment-like notifications with an amount '
                              'are kept. Nothing is sent off the phone, and '
                              'nothing reaches your ledger until you confirm '
                              'it.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.outline,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(
    BuildContext context,
    Detection detection,
  ) async {
    final capture = context.read<CaptureProvider>();
    final txs = context.read<TransactionsProvider>();
    final settings = context.read<SettingsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final goals = context.read<GoalsProvider>();
    final currency = settings.currencyCode;
    final messenger = ScaffoldMessenger.of(context);
    final before = MoneyPlan.snapshotFor(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
    );
    final tx = await capture.accept(detection, txs);
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
          'Recorded ${fmtMoney(tx.amount, currency)} · '
          '${categoryById(tx.categoryId).label}',
        ),
      ),
    );
  }

  Future<void> _acceptAll(
    BuildContext context,
    CaptureProvider capture,
    TransactionsProvider txs,
  ) async {
    final settings = context.read<SettingsProvider>();
    final upcoming = context.read<UpcomingProvider>();
    final goals = context.read<GoalsProvider>();
    final currency = settings.currencyCode;
    final messenger = ScaffoldMessenger.of(context);
    final items = capture.all.toList();
    final before = MoneyPlan.snapshotFor(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
    );
    var total = 0.0;
    var hasExpense = false;
    for (final detection in items) {
      final tx = await capture.accept(detection, txs);
      total += tx.amount;
      hasExpense = hasExpense || tx.type.isExpense;
    }
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
      isExpense: hasExpense,
      currency: currency,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Recorded ${items.length} payments · ${fmtMoney(total, currency)}',
        ),
      ),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({
    required this.detection,
    required this.currencyCode,
    required this.onAccept,
    required this.onIgnore,
  });

  final Detection detection;
  final String currencyCode;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final category = categoryById(detection.categoryId);
    final income = detection.type.isIncome;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
        child: Column(
          children: [
            Row(
              children: [
                CategoryBadge(category: category, size: 40),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detection.ledgerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        '${detection.appLabel} · '
                        '${DateFormat('d MMM · h:mm a').format(detection.capturedAt)} · '
                        '${category.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${income ? '+' : '-'}${fmtMoney(detection.amount, currencyCode)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: income ? AppColors.income : AppColors.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onIgnore,
                  child: const Text('Ignore'),
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: onAccept,
                  icon: const Icon(LucideIcons.plus, size: 15),
                  label: const Text('Add'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    visualDensity: VisualDensity.compact,
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

class _AccessBanner extends StatefulWidget {
  const _AccessBanner({required this.autoCapture});

  final bool autoCapture;

  @override
  State<_AccessBanner> createState() => _AccessBannerState();
}

class _AccessBannerState extends State<_AccessBanner> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final granted = await CaptureService.hasAccess();
    if (!mounted) return;
    setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final granted = _granted;

    if (granted == true && widget.autoCapture) {
      return const SizedBox.shrink();
    }

    final Color accent;
    final String title;
    final String body;
    if (!widget.autoCapture) {
      accent = AppColors.warn;
      title = 'Automatic tracking is off';
      body = 'Turn it on in Settings to watch payment notifications.';
    } else if (granted == false) {
      accent = AppColors.expense;
      title = 'Notification access is not granted';
      body = 'Android must allow DailyMoney to read notifications before '
          'payments can be detected.';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.triangleAlert, size: 16, color: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            body,
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.outline,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.autoCapture)
                TextButton.icon(
                  onPressed: () async {
                    await CaptureService.openSettings();
                    await _check();
                  },
                  icon: const Icon(LucideIcons.settings, size: 15),
                  label: const Text('Open settings'),
                ),
              TextButton.icon(
                onPressed: _check,
                icon: const Icon(LucideIcons.refreshCw, size: 15),
                label: const Text('Check again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
