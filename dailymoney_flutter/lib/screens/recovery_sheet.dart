import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/money_plan.dart';
import '../services/recovery.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/plan_widgets.dart';

/// Builds a short, realistic recovery plan for overspending.
class RecoverySheet extends StatefulWidget {
  const RecoverySheet({super.key});

  @override
  State<RecoverySheet> createState() => _RecoverySheetState();
}

class _RecoverySheetState extends State<RecoverySheet> {
  int _requestedDays = 0;

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
    final snapshot = plan.snapshot;
    final over = math.max(
      math.max(0.0, -snapshot.monthlyLeft),
      math.max(0.0, -snapshot.remainingToday),
    );
    final allowance = snapshot.baseAllowance > 0
        ? snapshot.baseAllowance
        : snapshot.allowance;
    final canReduce = allowance > 0.005;
    final active = settings.recoveryActive && settings.recoveryDailyCut > 0;
    final finished = settings.recoveryActive && settings.recoveryFinished(now);

    final requested = _requestedDays > 0 ? _requestedDays : 7;
    final window = math.max(1, math.min(requested, snapshot.daysLeft));
    final rawCut = over > 0 ? (over / math.max(1, window)).ceilToDouble() : 0.0;
    final maxCut = allowance > 0 ? math.max(1.0, allowance * 0.5) : rawCut;
    final cut = canReduce ? (rawCut > maxCut ? maxCut : rawCut) : 0.0;
    final days = canReduce && cut > 0
        ? math.min(
            snapshot.daysLeft,
            math.min(60, math.max(window, (over / cut).ceil())),
          )
        : 0;
    final covers = RecoveryPlanner.coverage(cut, days);
    final capped = rawCut > cut + 0.005;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.warn.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.heartPulse,
                    size: 19,
                    color: AppColors.warn,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recovery plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'A short plan that asks a little less each day until the '
              'overspend is covered. Bills, savings and essentials are '
              'protected first.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 14),
            if (active) ...[
              _ActiveCard(
                settings: settings,
                currency: currency,
                finished: finished,
                now: now,
                onEnd: () => _endPlan(context, settings),
              ),
              const SizedBox(height: 10),
              Text(
                finished
                    ? 'Finish the plan to clear it. Any remaining overspend '
                        'can be recovered with a new plan.'
                    : 'This plan stays fixed until it ends. Ending it restores '
                        'your normal allowance immediately, and you can start a '
                        'different window.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 14),
            ] else if (over > 0.005) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    children: [
                      PlanRow(
                        label: 'Overspend to recover',
                        value: fmtMoney(over, currency),
                        color: AppColors.expense,
                        emphasized: true,
                        note: snapshot.monthlyLeft < 0
                            ? 'The month is over its plan'
                            : 'Today is over its allowance',
                      ),
                      PlanRow(
                        label: 'Daily allowance before recovery',
                        value: fmtMoney(allowance, currency),
                      ),
                      PlanRow(
                        label: snapshot.daysLeft == 1
                            ? 'Day left this month'
                            : 'Days left this month',
                        value: '${snapshot.daysLeft}',
                      ),
                      if (plan.savingsCommitment > 0 ||
                          plan.emergencyBuffer > 0) ...[
                        const Divider(height: 12),
                        PlanRow(
                          label: 'Still protected',
                          value: fmtMoney(
                            plan.savingsCommitment + plan.emergencyBuffer,
                            currency,
                          ),
                          color: scheme.primary,
                          note: 'Savings and buffer are never used to fix '
                              'day-to-day overspending',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!canReduce) ...[
                const PlanNote(
                  icon: LucideIcons.info,
                  text: 'Your daily allowance is already ₹0 after this '
                      'month\'s spending. A recovery plan cannot lower it '
                      'further; bills and essentials are already protected. '
                      'It becomes available when there is allowance to reduce.',
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ] else ...[
                const PlanSectionTitle(
                  title: 'Choose a window',
                  subtitle: 'Longer windows ask for a smaller daily cut.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in [7, 14, 21, 30])
                      ChoiceChip(
                        label: Text('$option days'),
                        selected: requested == option,
                        onSelected: (_) =>
                            setState(() => _requestedDays = option),
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Card(
                  color: scheme.primary.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Big(
                                label: 'Less per day',
                                value: fmtMoney(cut, currency),
                                color: AppColors.warn,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Big(
                                label: 'Plan length',
                                value: '$days ${days == 1 ? 'day' : 'days'}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Covers ${fmtMoney(covers, currency)} of '
                                '${fmtMoney(over, currency)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.outline,
                                ),
                              ),
                            ),
                            Icon(
                              covers + 0.005 >= over
                                  ? LucideIcons.badgeCheck
                                  : LucideIcons.circleAlert,
                              size: 16,
                              color: covers + 0.005 >= over
                                  ? AppColors.income
                                  : AppColors.warn,
                            ),
                          ],
                        ),
                        if (capped) ...[
                          const SizedBox(height: 10),
                          PlanNote(
                            icon: LucideIcons.info,
                            text:
                                'The daily cut is limited to half of today\'s '
                                'allowance (${fmtMoney(maxCut, currency)}), so '
                                'the plan runs for $days days instead. Essentials '
                                'keep their room.',
                          ),
                        ],
                        if (requested > snapshot.daysLeft) ...[
                          const SizedBox(height: 10),
                          PlanNote(
                            icon: LucideIcons.info,
                            text: 'Only ${snapshot.daysLeft} '
                                '${snapshot.daysLeft == 1 ? 'day is' : 'days are'} '
                                'left this month, so the plan is capped at '
                                '$days ${days == 1 ? 'day' : 'days'}.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: cut <= 0 || days <= 0
                      ? null
                      : () => _start(
                            context,
                            cut: cut,
                            days: days,
                            target: over,
                          ),
                  icon: const Icon(LucideIcons.play, size: 18),
                  label: const Text('Start recovery plan'),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can end the plan at any time. It only changes the '
                  'discretionary daily allowance — no money is moved or taken.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: scheme.outline,
                  ),
                ),
              ],
            ] else
              _NoOverspend(onClose: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _start(
    BuildContext context, {
    required double cut,
    required int days,
    required double target,
  }) async {
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await settings.startRecovery(
      dailyCut: cut,
      days: days,
      target: target,
      now: DateTime.now(),
    );
    if (!mounted) return;
    Navigator.of(this.context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Recovery plan started · ${fmtMoney(cut, settings.currencyCode)} '
          'less per day for $days days',
        ),
      ),
    );
  }

  Future<void> _endPlan(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End recovery plan?'),
        content: const Text(
          'Your normal daily allowance comes back immediately. The overspend '
          'itself is not erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End plan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<SettingsProvider>().dismissRecovery();
    if (!context.mounted) return;
    Navigator.pop(context);
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.settings,
    required this.currency,
    required this.finished,
    required this.now,
    required this.onEnd,
  });

  final SettingsProvider settings;
  final String currency;
  final bool finished;
  final DateTime now;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final day = settings.recoveryDayNumber(now);
    final remaining = math.max(0, settings.recoveryDays - day + 1);
    return Card(
      color: AppColors.warn.withValues(alpha: 0.09),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  finished ? LucideIcons.badgeCheck : LucideIcons.heartPulse,
                  size: 17,
                  color: finished ? AppColors.income : AppColors.warn,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    finished ? 'Recovery plan complete' : 'Plan is active',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: finished ? AppColors.income : AppColors.warn,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onEnd,
                  child: Text(finished ? 'Finish' : 'End'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!finished)
              Text(
                'Day $day of ${settings.recoveryDays} · $remaining days left',
                style: TextStyle(fontSize: 12.5, color: scheme.outline),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Big(
                    label: 'Daily cut',
                    value: fmtMoney(settings.recoveryDailyCut, currency),
                    color: AppColors.warn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Big(
                    label: 'Target',
                    value: fmtMoney(settings.recoveryTarget, currency),
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

class _NoOverspend extends StatelessWidget {
  const _NoOverspend({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.badgeCheck,
                size: 24,
                color: AppColors.income,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No recovery needed',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You are not over today\'s allowance or this month\'s plan. '
              'A recovery plan only starts when there is a gap to close.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onClose,
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.label, required this.value, this.color});

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
          style: TextStyle(fontSize: 10.5, color: scheme.outline),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: color ?? scheme.onSurface,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
