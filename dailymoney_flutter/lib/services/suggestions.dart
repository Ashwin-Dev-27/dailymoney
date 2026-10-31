import 'dart:math' as math;

import '../models/category.dart';
import '../models/tx.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../utils/format.dart';
import 'money_plan.dart';

enum SuggestionTone { positive, warning, neutral }

enum SuggestionIcon {
  budget,
  warning,
  category,
  calendar,
  goal,
  trend,
  recurring,
  sparkles,
}

/// One personalised, rule-based tip.
class Suggestion {
  const Suggestion({
    required this.id,
    required this.title,
    required this.body,
    this.tone = SuggestionTone.neutral,
    this.icon = SuggestionIcon.sparkles,
  });

  final String id;
  final String title;
  final String body;
  final SuggestionTone tone;
  final SuggestionIcon icon;
}

/// Builds personalised tips from what actually happened in the ledger.
///
/// Everything is computed locally from the user's own numbers — no model calls
/// and no network access.
class SuggestionEngine {
  const SuggestionEngine._();

  static List<Suggestion> build({
    required SettingsProvider settings,
    required TransactionsProvider txs,
    required UpcomingProvider upcoming,
    required GoalsProvider goals,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final month = DateTime(today.year, today.month);
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final currency = settings.currencyCode;

    final totals = txs.totalsFor(month);
    final snapshot = MoneyPlan.snapshotFor(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
      today: today,
    );

    final tips = <Suggestion>[];

    if (!snapshot.hasBudget) {
      tips.add(const Suggestion(
        id: 'set-budget',
        title: 'Set a monthly budget',
        body: 'A budget turns your spending into a daily allowance and unlocks '
            'pace alerts. Add one in Settings.',
        icon: SuggestionIcon.budget,
      ));
    }

    if (snapshot.hasBudget && snapshot.monthlyLeft < 0) {
      tips.add(Suggestion(
        id: 'over-month',
        title: 'You are over your monthly budget',
        body: '${fmtMoney(-snapshot.monthlyLeft, currency)} past the plan with '
            '${snapshot.daysLeft} day${snapshot.daysLeft == 1 ? '' : 's'} left. '
            'Pause optional spending or move a bill to next month.',
        tone: SuggestionTone.warning,
        icon: SuggestionIcon.warning,
      ));
    } else if (snapshot.hasBudget &&
        snapshot.allowance > 0 &&
        snapshot.remainingToday <= snapshot.allowance * 0.2) {
      tips.add(Suggestion(
        id: 'today-tight',
        title: snapshot.remainingToday < 0
            ? 'Today is over the allowance'
            : 'Only a little left for today',
        body: snapshot.remainingToday < 0
            ? '${fmtMoney(-snapshot.remainingToday, currency)} over today\'s '
                '${fmtMoney(snapshot.allowance, currency)}. Tomorrow starts '
                'fresh with a new allowance.'
            : '${fmtMoney(snapshot.remainingToday, currency)} left of today\'s '
                '${fmtMoney(snapshot.allowance, currency)}. Cook at home or '
                'delay non-essentials to stay on track.',
        tone: SuggestionTone.warning,
        icon: SuggestionIcon.warning,
      ));
    }

    // Category concentration.
    final byCategory = txs.expenseByCategory(month);
    if (byCategory.isNotEmpty) {
      final total = byCategory.values.fold(0.0, (a, b) => a + b);
      final top = byCategory.entries.first;
      final share = total <= 0 ? 0.0 : top.value / total;
      if (share >= 0.35) {
        final cat = categoryById(top.key);
        tips.add(Suggestion(
          id: 'category-share-${top.key}',
          title: '${cat.label} is ${(share * 100).round()}% of your spending',
          body:
              '${fmtMoney(top.value, currency)} of ${fmtMoney(total, currency)} '
              'this month. A small cap on ${cat.label.toLowerCase()} frees up '
              'room for everything else.',
          icon: SuggestionIcon.category,
        ));
      }

      // Fastest-rising category versus the same point last month.
      final lastMonth = DateTime(month.year, month.month - 1);
      final lastByCategory = <String, double>{};
      for (final t in txs.all) {
        if (t.type != TxType.expense) continue;
        if (t.date.year != lastMonth.year || t.date.month != lastMonth.month) {
          continue;
        }
        if (t.date.day > today.day) continue;
        lastByCategory[t.categoryId] =
            (lastByCategory[t.categoryId] ?? 0) + t.amount;
      }
      String? spikeId;
      var spikeDelta = 0.0;
      for (final entry in byCategory.entries.take(4)) {
        final before = lastByCategory[entry.key] ?? 0;
        if (before < 50) continue;
        final delta = entry.value - before;
        if (entry.value > before * 1.4 && delta > spikeDelta) {
          spikeDelta = delta;
          spikeId = entry.key;
        }
      }
      if (spikeId != null) {
        final cat = categoryById(spikeId);
        tips.add(Suggestion(
          id: 'category-spike-$spikeId',
          title: '${cat.label} is climbing',
          body: '${fmtMoney(spikeDelta, currency)} more than this point last '
              'month. Check whether any of it was a one-off.',
          tone: SuggestionTone.warning,
          icon: SuggestionIcon.trend,
        ));
      }
    }

    // Bills due in the next week.
    final weekEnd = today.add(const Duration(days: 7));
    final soon = upcoming.all.where((item) {
      final due =
          DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);
      final start = DateTime(today.year, today.month, today.day);
      return !due.isBefore(start) && !due.isAfter(weekEnd);
    }).toList();
    if (soon.isNotEmpty) {
      final reserved = soon.fold(0.0, (sum, item) => sum + item.amount);
      tips.add(Suggestion(
        id: 'bills-week',
        title:
            '${soon.length} bill${soon.length == 1 ? '' : 's'} due this week',
        body: '${fmtMoney(reserved, currency)} is already set aside. Next up: '
            '${soon.first.title} (${fmtMoney(soon.first.amount, currency)}).',
        icon: SuggestionIcon.calendar,
      ));
    }

    // Goal timing.
    final goal = goals.nextGoal;
    if (goal != null) {
      if (goal.isOverdue(today)) {
        tips.add(Suggestion(
          id: 'goal-overdue-${goal.id}',
          title: '${goal.title} passed its target date',
          body: '${fmtMoney(goal.remaining, currency)} still to go. Pick a new '
              'date or add a little this week to restart momentum.',
          tone: SuggestionTone.warning,
          icon: SuggestionIcon.goal,
        ));
      } else if (goal.progress >= 0.75) {
        tips.add(Suggestion(
          id: 'goal-close-${goal.id}',
          title: '${goal.title} is ${(goal.progress * 100).round()}% funded',
          body:
              'Only ${fmtMoney(goal.remaining, currency)} left. One more top-up '
              'could finish it.',
          tone: SuggestionTone.positive,
          icon: SuggestionIcon.goal,
        ));
      } else if (goal.targetDate != null) {
        final monthly = goal.monthlyNeeded(today);
        tips.add(Suggestion(
          id: 'goal-plan-${goal.id}',
          title: 'Save ${fmtMoney(monthly, currency)}/month for ${goal.title}',
          body: 'That keeps the goal on schedule for '
              '${monthLabel(goal.targetDate!)} with '
              '${fmtMoney(goal.remaining, currency)} to go.',
          icon: SuggestionIcon.goal,
        ));
      }
    }

    // Repeated payments worth reviewing.
    final repeats = <String, ({String title, int count, double total})>{};
    for (final t in txs.all) {
      if (t.type != TxType.expense) continue;
      if (t.date.year != month.year || t.date.month != month.month) continue;
      final key = t.title.trim().toLowerCase();
      if (key.isEmpty) continue;
      final prev = repeats[key];
      repeats[key] = (
        title: t.title.trim(),
        count: (prev?.count ?? 0) + 1,
        total: (prev?.total ?? 0) + t.amount,
      );
    }
    final recurring = repeats.values
        .where((r) => r.count >= 3)
        .fold<({String title, int count, double total})?>(
          null,
          (best, r) => best == null || r.total > best.total ? r : best,
        );
    if (recurring != null) {
      tips.add(Suggestion(
        id: 'recurring-${recurring.title.toLowerCase()}',
        title: '"${recurring.title}" appeared ${recurring.count} times',
        body:
            '${fmtMoney(recurring.total, currency)} in total this month. If it '
            'is a habit rather than a bill, a weekly cap helps.',
        icon: SuggestionIcon.recurring,
      ));
    }

    // No-spend days. Only meaningful once there is some activity to compare
    // against — a brand-new ledger would otherwise celebrate every empty day.
    var noSpendDays = 0;
    final firstDay = DateTime(month.year, month.month, 1);
    for (var i = 0; i < today.day; i++) {
      final day = firstDay.add(Duration(days: i));
      if (txs.expenseOn(day) == 0) noSpendDays++;
    }
    if (byCategory.isNotEmpty && noSpendDays >= 5) {
      tips.add(Suggestion(
        id: 'no-spend',
        title: '$noSpendDays no-spend days this month',
        body: 'That is real progress. Keeping one or two more this week would '
            'protect the rest of your allowance.',
        tone: SuggestionTone.positive,
        icon: SuggestionIcon.sparkles,
      ));
    }

    // Ahead of plan.
    final elapsed = today.day / daysInMonth;
    if (snapshot.hasBudget &&
        snapshot.monthlyLeft > 0 &&
        elapsed >= 0.6 &&
        snapshot.monthlyLeft > snapshot.budget * 0.2) {
      tips.add(Suggestion(
        id: 'ahead',
        title: 'You are ahead of plan',
        body:
            '${fmtMoney(snapshot.monthlyLeft, currency)} of the budget is still '
            'free with ${snapshot.daysLeft} days to go. Consider moving some to '
            'a savings goal.',
        tone: SuggestionTone.positive,
        icon: SuggestionIcon.budget,
      ));
    }

    if (settings.carryForward && snapshot.rolledOver > 0) {
      tips.add(Suggestion(
        id: 'rolled-over',
        title: '${fmtMoney(snapshot.rolledOver, currency)} rolled over',
        body: 'Underspending earlier this month raised today\'s allowance to '
            '${fmtMoney(snapshot.allowance, currency)}.',
        tone: SuggestionTone.positive,
        icon: SuggestionIcon.trend,
      ));
    }

    if (tips.isEmpty && txs.isEmpty) {
      tips.add(const Suggestion(
        id: 'start',
        title: 'Start with one expense',
        body: 'Record a purchase and DailyMoney will begin spotting patterns '
            'and suggesting ways to keep more of your money.',
        icon: SuggestionIcon.sparkles,
      ));
    }

    // Keep the list short enough to act on.
    final ordered = tips.take(6).toList();
    if (ordered.isEmpty && totals.expense > 0) {
      ordered.add(const Suggestion(
        id: 'steady',
        title: 'Nothing unusual this month',
        body: 'Your spending is in line with the plan. Keep recording as you '
            'go so the daily allowance stays accurate.',
        tone: SuggestionTone.positive,
        icon: SuggestionIcon.sparkles,
      ));
    }
    return ordered.isEmpty ? const [] : List.unmodifiable(ordered);
  }

  /// Days between two dates, used by callers that need a pace figure.
  static int daysBetween(DateTime a, DateTime b) =>
      math.max(0, b.difference(a).inDays);
}
