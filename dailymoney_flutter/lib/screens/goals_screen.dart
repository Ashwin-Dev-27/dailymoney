import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/savings_goal.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import 'goal_sheet.dart';

/// Savings goals: overall progress plus one card per goal.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final goals = context.watch<GoalsProvider>();
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currencyCode;

    return Scaffold(
      appBar: AppBar(
        title: Text('Savings goals', style: TextStyle(color: scheme.onSurface)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context),
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('New goal'),
      ),
      body: goals.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EmptyState(
                    icon: LucideIcons.target,
                    title: 'No savings goals yet',
                    message:
                        'Give the money you keep a purpose — an emergency fund, '
                        'a trip, or your next big purchase.',
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _openSheet(context),
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Create your first goal'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
              children: [
                _SummaryCard(
                  saved: goals.totalSaved,
                  target: goals.totalTarget,
                  currencyCode: currency,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your goals',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                          color: scheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    Text(
                      '${goals.active.length} active',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final goal in goals.all) ...[
                  _GoalCard(
                    goal: goal,
                    currencyCode: currency,
                    onTap: () => _openSheet(context, existing: goal),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.info, size: 13, color: scheme.outline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Goals are a plan for money you keep. Adding to a goal '
                        'does not move money out of your balance or budget.',
                        style: TextStyle(fontSize: 11.5, color: scheme.outline),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static void _openSheet(BuildContext context, {SavingsGoal? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GoalSheet(existing: existing),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.saved,
    required this.target,
    required this.currencyCode,
  });

  final double saved;
  final double target;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12B98A), Color(0xFF0B7A61)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.target,
                size: 17,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 7),
              Text(
                'Set aside so far',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fmtMoney(saved, currencyCode),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          Text(
            'of ${fmtMoney(target, currencyCode)} across all goals',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              backgroundColor: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(ratio * 100).round()}% funded · '
            '${fmtMoney((target - saved).clamp(0, double.infinity).toDouble(), currencyCode)} to go',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.currencyCode,
    required this.onTap,
  });

  final SavingsGoal goal;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final overdue = goal.isOverdue(now);
    final accent = goal.isComplete
        ? AppColors.income
        : overdue
            ? AppColors.expense
            : scheme.primary;
    final monthly = goal.monthlyNeeded(now);
    final months = goal.monthsLeft(now);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      goal.isComplete
                          ? LucideIcons.check
                          : LucideIcons.piggyBank,
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          goal.isComplete
                              ? 'Goal reached'
                              : goal.targetDate == null
                                  ? '${fmtMoney(goal.remaining, currencyCode)} to go'
                                  : '${fmtMoney(goal.remaining, currencyCode)} to go · ${dateLong(goal.targetDate!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: overdue ? AppColors.expense : scheme.outline,
                            fontWeight:
                                overdue ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Goal options',
                    onSelected: (value) {
                      if (value == 'edit') {
                        onTap();
                      } else if (value == 'add') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => GoalContributeSheet(goal: goal),
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'add', child: Text('Add money')),
                      PopupMenuItem(value: 'edit', child: Text('Edit goal')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  valueColor: AlwaysStoppedAnimation(accent),
                  backgroundColor:
                      scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${fmtMoney(goal.saved, currencyCode)} of '
                      '${fmtMoney(goal.target, currencyCode)} · '
                      '${(goal.progress * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.outline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Without a target date there is no honest per-month figure,
                  // so show nothing rather than labelling the remainder "/mo".
                  if (!goal.isComplete && (overdue || months != null))
                    Text(
                      overdue
                          ? 'Target date passed'
                          : '${fmtMoney(monthly, currencyCode)}/mo · '
                              '$months mo',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: goal.isComplete
                          ? null
                          : () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => GoalContributeSheet(goal: goal),
                              );
                            },
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: Text(goal.isComplete ? 'Complete' : 'Add money'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
