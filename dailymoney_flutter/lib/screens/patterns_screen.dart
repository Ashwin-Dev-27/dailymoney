import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/habits.dart';
import '../services/leaks.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/plan_widgets.dart';

/// Evidence-backed spending patterns and habit observations.
///
/// One screen, two short sections — deliberately not a dashboard per idea.
class PatternsScreen extends StatefulWidget {
  const PatternsScreen({super.key, this.initialTab = 0});

  /// 0 shows patterns to check, 1 shows habit insights.
  final int initialTab;

  @override
  State<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends State<PatternsScreen> {
  late int _tab = widget.initialTab.clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final txs = context.watch<TransactionsProvider>();
    final upcoming = context.watch<UpcomingProvider>();
    final currency = settings.currencyCode;
    final leaks = LeakDetector.build(
      transactions: txs.all,
      settings: settings,
      trackedBillTitles: upcoming.all.map((e) => e.title),
    );
    final habits = HabitEngine.build(
      transactions: txs.all,
      settings: settings,
    );
    final noHistory = txs.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Patterns',
          style: TextStyle(color: scheme.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          const PlanNote(
            icon: LucideIcons.scanSearch,
            text: 'These are observations from your own records, not '
                'accusations or fraud reports. Every pattern shows the '
                'transactions behind it so you can judge it yourself.',
          ),
          const SizedBox(height: 14),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                icon: const Icon(LucideIcons.searchCheck, size: 16),
                label: Text(
                    'To check${leaks.isEmpty ? '' : ' (${leaks.length})'}'),
              ),
              ButtonSegment(
                value: 1,
                icon: const Icon(LucideIcons.sparkles, size: 16),
                label: Text(
                  'Habits${habits.isEmpty ? '' : ' (${habits.length})'}',
                ),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 18),
          if (noHistory)
            const EmptyState(
              icon: LucideIcons.scanSearch,
              title: 'Nothing to look at yet',
              message: 'Record a couple of weeks of spending and patterns '
                  'will appear here with their evidence.',
            )
          else if (_tab == 0) ...[
            const PlanSectionTitle(
              title: 'Worth a second look',
              subtitle: 'Repeated, rising, duplicate or untracked charges.',
            ),
            if (leaks.isEmpty)
              const _QuietCard(
                icon: LucideIcons.badgeCheck,
                title: 'No patterns to flag',
                message: 'There is either no unusual pattern in your recent '
                    'spending, or not enough history for a fair comparison. '
                    'That is a normal result, not a missing feature.',
              )
            else
              for (final insight in leaks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LeakCard(
                    insight: insight,
                    currency: currency,
                  ),
                ),
          ] else ...[
            const PlanSectionTitle(
              title: 'How you spend',
              subtitle: 'Practical observations, never automatic advice.',
            ),
            if (habits.isEmpty)
              const _QuietCard(
                icon: LucideIcons.sparkles,
                title: 'Not enough history for habits',
                message: 'Habit insights need about three weeks of expenses '
                    'before they can say anything honest. Keep recording and '
                    'check back.',
              )
            else
              for (final habit in habits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HabitCard(
                    habit: habit,
                    currency: currency,
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _LeakCard extends StatelessWidget {
  const _LeakCard({required this.insight, required this.currency});

  final LeakInsight insight;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (insight.kind) {
      LeakKind.repeated => LucideIcons.repeat,
      LeakKind.categoryRise => LucideIcons.trendingUp,
      LeakKind.duplicate => LucideIcons.copy,
      LeakKind.recurring => LucideIcons.calendarClock,
      LeakKind.unusual => LucideIcons.scale,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.warn.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: AppColors.warn),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        insight.body,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  fmtMoney(insight.amount, currency),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  'Evidence (${insight.evidence.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                children: [
                  for (final tx in insight.evidence)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${dayLabel(tx.date)} · ${tx.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmtMoney(tx.personalExpense, currency),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit, required this.currency});

  final HabitInsight habit;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (habit.tone) {
      HabitTone.positive => AppColors.income,
      HabitTone.warning => AppColors.warn,
      HabitTone.neutral => scheme.primary,
    };
    final icon = switch (habit.icon) {
      HabitIcon.weekend => LucideIcons.calendarHeart,
      HabitIcon.category => LucideIcons.pieChart,
      HabitIcon.repeat => LucideIcons.repeat,
      HabitIcon.transport => LucideIcons.bus,
      HabitIcon.noSpend => LucideIcons.badgeCheck,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    habit.body,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuietCard extends StatelessWidget {
  const _QuietCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
        child: Column(
          children: [
            Icon(icon, size: 26, color: scheme.outline),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
