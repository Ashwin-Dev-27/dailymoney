import 'dart:math' as math;

import '../models/tx.dart';
import '../providers/settings_provider.dart';

/// A possible gap in today's records.
class MissingExpenseCheck {
  const MissingExpenseCheck({
    required this.shouldAsk,
    required this.typicalDaily,
    required this.todayExpense,
    required this.yesterdayExpense,
    required this.activeDays,
  });

  final bool shouldAsk;
  final double typicalDaily;
  final double todayExpense;
  final double yesterdayExpense;
  final int activeDays;

  String get message {
    if (yesterdayExpense <= 0 && todayExpense <= 0) {
      return 'No spending has been recorded since yesterday. Did you pay cash?';
    }
    return 'Your recorded spending looks unusually low today. '
        'Did you make any cash purchases?';
  }
}

/// Detects likely missing cash expenses from the shape of the ledger.
///
/// This only asks a question. It never invents a transaction or subtracts an
/// estimate from a real balance.
class MissingExpenseDetector {
  const MissingExpenseDetector._();

  static MissingExpenseCheck check({
    required List<Tx> transactions,
    required SettingsProvider settings,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    if (today.hour < 17) {
      return const MissingExpenseCheck(
        shouldAsk: false,
        typicalDaily: 0,
        todayExpense: 0,
        yesterdayExpense: 0,
        activeDays: 0,
      );
    }
    if (settings.missingExpenseDismissed(today)) {
      return const MissingExpenseCheck(
        shouldAsk: false,
        typicalDaily: 0,
        todayExpense: 0,
        yesterdayExpense: 0,
        activeDays: 0,
      );
    }

    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 21));
    final dayTotals = <String, double>{};
    var todayExpense = 0.0;
    var yesterdayExpense = 0.0;
    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));
    for (final tx in transactions) {
      if (!tx.type.isExpense || tx.isSettlement) continue;
      final amount = tx.personalExpense;
      if (amount <= 0) continue;
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (day.isBefore(start)) continue;
      if (day == DateTime(today.year, today.month, today.day)) {
        todayExpense += amount;
        continue;
      }
      if (day == yesterday) yesterdayExpense += amount;
      final key = '${day.year}-${day.month}-${day.day}';
      dayTotals[key] = (dayTotals[key] ?? 0) + amount;
    }

    // A brand new ledger has no reliable "normal" to compare against.
    final activeDays = dayTotals.values.where((v) => v > 0).length;
    if (activeDays < 4) {
      return MissingExpenseCheck(
        shouldAsk: false,
        typicalDaily: 0,
        todayExpense: todayExpense,
        yesterdayExpense: yesterdayExpense,
        activeDays: activeDays,
      );
    }

    final total = dayTotals.values.fold(0.0, (a, b) => a + b);
    final typical = total / math.max(1, activeDays);
    final lowToday = todayExpense <= typical * 0.15;
    final quietYesterday = yesterdayExpense <= 0;
    final shouldAsk = lowToday && (todayExpense <= 0 || quietYesterday);

    return MissingExpenseCheck(
      shouldAsk: shouldAsk,
      typicalDaily: typical,
      todayExpense: todayExpense,
      yesterdayExpense: yesterdayExpense,
      activeDays: activeDays,
    );
  }
}
