import 'dart:math' as math;

import '../models/category.dart';
import '../models/tx.dart';
import '../providers/settings_provider.dart';
import '../utils/format.dart';

enum LeakKind { repeated, categoryRise, duplicate, recurring, unusual }

/// One evidence-backed pattern worth checking. Never a fraud finding.
class LeakInsight {
  const LeakInsight({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.amount,
    required this.evidence,
  });

  final String id;
  final LeakKind kind;
  final String title;
  final String body;

  /// The money involved in the pattern, not a claim that it was wasted.
  final double amount;
  final List<Tx> evidence;
}

/// Finds spending patterns that may deserve a second look.
///
/// Every insight is derived from actual transactions, includes the evidence,
/// and uses cautious wording. The detector stays silent when there is not
/// enough history to make a fair comparison.
class LeakDetector {
  const LeakDetector._();

  static List<LeakInsight> build({
    required List<Tx> transactions,
    required SettingsProvider settings,
    Iterable<String> trackedBillTitles = const [],
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final expenses = transactions
        .where((t) => t.type.isExpense && !t.isSettlement)
        .where((t) => t.personalExpense > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (expenses.length < 12) return const [];

    final oldest = expenses.last.date;
    final spanDays = DateTime(today.year, today.month, today.day)
        .difference(DateTime(oldest.year, oldest.month, oldest.day))
        .inDays;
    if (spanDays < 14) return const [];

    final threshold = math.max(20.0, settings.monthlyBudget * 0.02);
    final currency = settings.currencyCode;
    final insights = <LeakInsight>[];

    _addRepeated(insights, expenses, today, currency);
    _addCategoryRise(insights, expenses, today, threshold, currency);
    _addDuplicates(insights, expenses, currency);
    _addRecurring(insights, expenses, trackedBillTitles, currency);
    _addMonthChange(insights, expenses, today, threshold, currency);

    insights.sort((a, b) => b.amount.compareTo(a.amount));
    final seen = <String>{};
    final out = <LeakInsight>[];
    for (final insight in insights) {
      if (!seen.add(insight.id)) continue;
      out.add(insight);
      if (out.length >= 5) break;
    }
    return List.unmodifiable(out);
  }

  static void _addRepeated(
    List<LeakInsight> out,
    List<Tx> expenses,
    DateTime today,
    String currency,
  ) {
    final start = today.subtract(const Duration(days: 13));
    final window = expenses.where((t) => !t.date.isBefore(start)).toList();
    if (window.isEmpty) return;
    final totalWindow = window.fold(0.0, (sum, t) => sum + t.personalExpense);
    final dailyAverage = totalWindow / 14;
    final groups = <String, List<Tx>>{};
    for (final tx in window) {
      final key = _normalTitle(tx.title);
      if (key.isEmpty) continue;
      groups.putIfAbsent(key, () => []).add(tx);
    }
    for (final entry in groups.entries) {
      final items = entry.value;
      if (items.length < 3) continue;
      final total = items.fold(0.0, (sum, t) => sum + t.personalExpense);
      final average = total / items.length;
      // "Small" is relative to this user's own daily spending.
      if (average > math.max(1.0, dailyAverage * 0.75)) continue;
      if (total < math.max(30.0, dailyAverage * 1.5)) continue;
      out.add(LeakInsight(
        id: 'repeat-${entry.key}',
        kind: LeakKind.repeated,
        title: 'Repeated payments to ${items.first.title.trim()}',
        body:
            '${items.length} payments totalling ${_money(total, currency)} in the last '
            '14 days. If this is intentional, no action is needed — it is only '
            'a pattern worth checking.',
        amount: total,
        evidence: items.take(6).toList(growable: false),
      ));
    }
  }

  static void _addCategoryRise(
    List<LeakInsight> out,
    List<Tx> expenses,
    DateTime today,
    double threshold,
    String currency,
  ) {
    final thisWeekStart = today.subtract(const Duration(days: 6));
    final lastWeekStart = today.subtract(const Duration(days: 13));
    final current = <String, double>{};
    final previous = <String, double>{};
    for (final tx in expenses) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (!day.isBefore(thisWeekStart)) {
        current[tx.categoryId] =
            (current[tx.categoryId] ?? 0) + tx.personalExpense;
      } else if (!day.isBefore(lastWeekStart) && day.isBefore(thisWeekStart)) {
        previous[tx.categoryId] =
            (previous[tx.categoryId] ?? 0) + tx.personalExpense;
      }
    }
    final rows = <({String id, double now, double before, double delta})>[];
    for (final entry in current.entries) {
      final before = previous[entry.key] ?? 0;
      if (before < math.max(25.0, threshold)) continue;
      final delta = entry.value - before;
      if (entry.value < before * 1.3) continue;
      if (delta < math.max(30.0, before * 0.25)) continue;
      rows.add((id: entry.key, now: entry.value, before: before, delta: delta));
    }
    rows.sort((a, b) => b.delta.compareTo(a.delta));
    for (final row in rows.take(2)) {
      final category = categoryById(row.id);
      out.add(LeakInsight(
        id: 'week-${row.id}',
        kind: LeakKind.categoryRise,
        title:
            '${category.label} is up ${_money(row.delta, currency)} this week',
        body:
            '${_money(row.now, currency)} this week versus ${_money(row.before, currency)} last '
            'week. Check whether the difference was a one-off.',
        amount: row.delta,
        evidence: expenses
            .where((t) =>
                t.categoryId == row.id && !t.date.isBefore(thisWeekStart))
            .take(6)
            .toList(growable: false),
      ));
    }
  }

  static void _addDuplicates(
    List<LeakInsight> out,
    List<Tx> expenses,
    String currency,
  ) {
    final groups = <String, List<Tx>>{};
    for (final tx in expenses) {
      final key = '${_normalTitle(tx.title)}|${tx.amount.toStringAsFixed(2)}';
      groups.putIfAbsent(key, () => []).add(tx);
    }
    for (final entry in groups.entries) {
      final items = entry.value..sort((a, b) => a.date.compareTo(b.date));
      if (items.length < 2) continue;
      var found = false;
      for (var i = 1; i < items.length; i++) {
        final gap = items[i].date.difference(items[i - 1].date).inHours.abs();
        if (gap <= 36) {
          found = true;
          break;
        }
      }
      if (!found) continue;
      final total = items.fold(0.0, (sum, tx) => sum + tx.personalExpense);
      out.add(LeakInsight(
        id: 'duplicate-${entry.key}',
        kind: LeakKind.duplicate,
        title: 'Possible duplicate: ${items.first.title.trim()}',
        body: '${items.length} entries with the same title and amount. If this '
            'was one payment, remove the extra entry. We cannot confirm a '
            'duplicate from the ledger alone.',
        amount: total,
        evidence: items.take(5).toList(growable: false),
      ));
    }
  }

  static void _addRecurring(
    List<LeakInsight> out,
    List<Tx> expenses,
    Iterable<String> trackedBillTitles,
    String currency,
  ) {
    final tracked = trackedBillTitles.map(_normalTitle).toSet();
    final cutoff = DateTime.now().subtract(const Duration(days: 200));
    final groups = <String, List<Tx>>{};
    for (final tx in expenses) {
      if (tx.date.isBefore(cutoff)) continue;
      final key = _normalTitle(tx.title);
      if (key.isEmpty || tracked.contains(key)) continue;
      groups.putIfAbsent(key, () => []).add(tx);
    }
    for (final entry in groups.entries) {
      final items = entry.value..sort((a, b) => a.date.compareTo(b.date));
      if (items.length < 3) continue;
      final months = items.map((t) => '${t.date.year}-${t.date.month}').toSet();
      final gaps = <int>[];
      for (var i = 1; i < items.length; i++) {
        gaps.add(items[i].date.difference(items[i - 1].date).inDays);
      }
      final monthly = months.length >= 3 &&
          gaps.isNotEmpty &&
          gaps.every((g) => g >= 20 && g <= 40);
      if (!monthly) continue;
      final recent = items.reversed.take(3).toList(growable: false);
      final average =
          recent.fold(0.0, (sum, t) => sum + t.personalExpense) / recent.length;
      out.add(LeakInsight(
        id: 'recurring-${entry.key}',
        kind: LeakKind.recurring,
        title: 'Recurring charge: ${items.last.title.trim()}',
        body:
            'About ${_money(average, currency)} roughly every month, but it is not in '
            'your upcoming bills. If it is a subscription, reserve it so it '
            'cannot surprise you.',
        amount: average,
        evidence: recent,
      ));
    }
  }

  static void _addMonthChange(
    List<LeakInsight> out,
    List<Tx> expenses,
    DateTime today,
    double threshold,
    String currency,
  ) {
    final month = DateTime(today.year, today.month);
    final previous = DateTime(today.year, today.month - 1);
    final currentByCat = <String, double>{};
    final previousByCat = <String, double>{};
    for (final tx in expenses) {
      if (tx.date.year == month.year && tx.date.month == month.month) {
        currentByCat[tx.categoryId] =
            (currentByCat[tx.categoryId] ?? 0) + tx.personalExpense;
      } else if (tx.date.year == previous.year &&
          tx.date.month == previous.month &&
          tx.date.day <= today.day) {
        previousByCat[tx.categoryId] =
            (previousByCat[tx.categoryId] ?? 0) + tx.personalExpense;
      }
    }
    for (final entry in currentByCat.entries) {
      final before = previousByCat[entry.key] ?? 0;
      if (before < threshold) continue;
      if (entry.value < before * 1.5) continue;
      final delta = entry.value - before;
      if (delta < math.max(threshold, before * 0.4)) continue;
      final category = categoryById(entry.key);
      out.add(LeakInsight(
        id: 'month-${entry.key}',
        kind: LeakKind.unusual,
        title: '${category.label} is much higher this month',
        body:
            '${_money(entry.value, currency)} so far versus ${_money(before, currency)} by this '
            'point last month. Look for a one-off before changing the plan.',
        amount: delta,
        evidence: expenses
            .where((t) =>
                t.categoryId == entry.key &&
                t.date.year == month.year &&
                t.date.month == month.month)
            .take(6)
            .toList(growable: false),
      ));
    }
  }

  static String _normalTitle(String title) =>
      title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _money(double value, String currency) =>
      fmtMoney(value, currency);
}
