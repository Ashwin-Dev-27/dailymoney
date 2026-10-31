import 'dart:math' as math;

import '../models/category.dart';
import '../models/tx.dart';
import '../providers/settings_provider.dart';
import '../utils/format.dart';

enum HabitTone { neutral, positive, warning }

enum HabitIcon { weekend, category, repeat, transport, noSpend }

/// A plain-language pattern from the user's own transaction history.
class HabitInsight {
  const HabitInsight({
    required this.id,
    required this.title,
    required this.body,
    this.tone = HabitTone.neutral,
    this.icon = HabitIcon.category,
  });

  final String id;
  final String title;
  final String body;
  final HabitTone tone;
  final HabitIcon icon;
}

/// Builds practical spending-habit observations.
///
/// Requires a real history before saying anything, so a new ledger never gets
/// confident-sounding advice built on two transactions.
class HabitEngine {
  const HabitEngine._();

  static List<HabitInsight> build({
    required List<Tx> transactions,
    required SettingsProvider settings,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final currency = settings.currencyCode;
    final expenses = transactions
        .where((t) => t.type.isExpense && !t.isSettlement)
        .where((t) => t.personalExpense > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (expenses.length < 12) return const [];
    final oldest = expenses.last.date;
    final span = DateTime(today.year, today.month, today.day)
        .difference(DateTime(oldest.year, oldest.month, oldest.day))
        .inDays;
    if (span < 21) return const [];

    final insights = <HabitInsight>[];
    _weekend(insights, expenses, today, currency);
    _dominantCategory(insights, expenses, today, currency);
    _repeated(insights, expenses, today, currency);
    _transportChange(insights, expenses, today, currency);
    _noSpendDays(insights, expenses, today);

    return List.unmodifiable(insights.take(4));
  }

  static void _weekend(
    List<HabitInsight> out,
    List<Tx> expenses,
    DateTime today,
    String currency,
  ) {
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 27));
    var weekendTotal = 0.0;
    var weekdayTotal = 0.0;
    var weekendDays = 0;
    var weekdayDays = 0;
    for (var i = 0; i < 28; i++) {
      final day = start.add(Duration(days: i));
      final weekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      if (weekend) {
        weekendDays++;
      } else {
        weekdayDays++;
      }
    }
    for (final tx in expenses) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (day.isBefore(start)) continue;
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        weekendTotal += tx.personalExpense;
      } else {
        weekdayTotal += tx.personalExpense;
      }
    }
    if (weekendDays == 0 || weekdayDays == 0) return;
    final weekendAvg = weekendTotal / weekendDays;
    final weekdayAvg = weekdayTotal / weekdayDays;
    final overall = (weekendTotal + weekdayTotal) / 28;
    final diff = weekendAvg - weekdayAvg;
    if (weekendAvg < weekdayAvg * 1.25 ||
        diff < math.max(10.0, overall * 0.2)) {
      return;
    }
    out.add(HabitInsight(
      id: 'weekend',
      title: 'Weekends run higher',
      body: 'You spend about ${fmtMoney(diff, currency)} more per weekend day '
          'than on weekdays. A small weekend cap could protect the rest of '
          'the month without changing your week.',
      tone: HabitTone.warning,
      icon: HabitIcon.weekend,
    ));
  }

  static void _dominantCategory(
    List<HabitInsight> out,
    List<Tx> expenses,
    DateTime today,
    String currency,
  ) {
    final month = DateTime(today.year, today.month);
    final byCategory = <String, double>{};
    var total = 0.0;
    for (final tx in expenses) {
      if (!sameMonth(tx.date, month)) continue;
      byCategory[tx.categoryId] =
          (byCategory[tx.categoryId] ?? 0) + tx.personalExpense;
      total += tx.personalExpense;
    }
    if (total <= 0 || byCategory.isEmpty) return;
    final top = byCategory.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final share = top.value / total;
    if (share < 0.35) return;
    final category = categoryById(top.key);
    out.add(HabitInsight(
      id: 'share-${top.key}',
      title: '${category.label} is ${(share * 100).round()}% of this month',
      body: '${fmtMoney(top.value, currency)} of ${fmtMoney(total, currency)}. '
          'That is not automatically a problem — it is the first place to look '
          'if you want to free up money.',
      icon: HabitIcon.category,
    ));
  }

  static void _repeated(
    List<HabitInsight> out,
    List<Tx> expenses,
    DateTime today,
    String currency,
  ) {
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 29));
    final window = expenses.where((t) => !t.date.isBefore(start)).toList();
    if (window.isEmpty) return;
    final daily = window.fold(0.0, (sum, t) => sum + t.personalExpense) / 30;
    final groups = <String, List<Tx>>{};
    for (final tx in window) {
      final key = tx.title.trim().toLowerCase();
      if (key.isEmpty) continue;
      groups.putIfAbsent(key, () => []).add(tx);
    }
    ({String key, List<Tx> items, double total})? best;
    for (final entry in groups.entries) {
      final items = entry.value;
      if (items.length < 4) continue;
      final total = items.fold(0.0, (sum, t) => sum + t.personalExpense);
      final average = total / items.length;
      if (average > math.max(1.0, daily * 0.8)) continue;
      if (total < math.max(30.0, daily * 2)) continue;
      if (best == null || total > best.total) {
        best = (key: entry.key, items: items, total: total);
      }
    }
    if (best == null) return;
    out.add(HabitInsight(
      id: 'repeat-${best.key}',
      title: 'Small purchases add up',
      body: '${best.items.length} payments to ${best.items.first.title.trim()} '
          'totalled ${fmtMoney(best.total, currency)} in the last 30 days. A '
          'weekly cap is usually easier than cutting it out entirely.',
      tone: HabitTone.warning,
      icon: HabitIcon.repeat,
    ));
  }

  static void _transportChange(
    List<HabitInsight> out,
    List<Tx> expenses,
    DateTime today,
    String currency,
  ) {
    final month = DateTime(today.year, today.month);
    final previous = DateTime(today.year, today.month - 1);
    var now = 0.0;
    var before = 0.0;
    for (final tx in expenses) {
      if (tx.categoryId != 'transport') continue;
      if (sameMonth(tx.date, month)) now += tx.personalExpense;
      if (sameMonth(tx.date, previous) && tx.date.day <= today.day) {
        before += tx.personalExpense;
      }
    }
    if (now <= 0 || before <= 0) return;
    final delta = now - before;
    if (delta.abs() < math.max(20.0, before * 0.2)) return;
    out.add(HabitInsight(
      id: 'transport',
      title:
          delta > 0 ? 'Transport is costing more' : 'Transport is costing less',
      body:
          '${fmtMoney(now, currency)} this month versus ${fmtMoney(before, currency)} '
          'by this point last month. ${delta > 0 ? 'Check whether a route or fare changed.' : 'That is a useful saving you can keep.'}',
      tone: delta > 0 ? HabitTone.warning : HabitTone.positive,
      icon: HabitIcon.transport,
    ));
  }

  static void _noSpendDays(
    List<HabitInsight> out,
    List<Tx> expenses,
    DateTime today,
  ) {
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 29));
    final days = <String>{};
    for (final tx in expenses) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (!day.isBefore(start)) {
        days.add('${day.year}-${day.month}-${day.day}');
      }
    }
    final noSpend = 30 - days.length;
    if (noSpend >= 6 && days.length >= 8) {
      out.add(HabitInsight(
        id: 'no-spend',
        title: '$noSpend no-spend days in the last 30',
        body:
            'That is real consistency. Keeping one or two more this week would '
            'protect the rest of your allowance.',
        tone: HabitTone.positive,
        icon: HabitIcon.noSpend,
      ));
    }
  }

  static bool sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}
