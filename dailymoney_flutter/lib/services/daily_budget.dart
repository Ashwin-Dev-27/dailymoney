import 'dart:math' as math;

import '../models/tx.dart';
import '../providers/settings_provider.dart';
import '../providers/upcoming_provider.dart';

/// A computed view of today's spending money.
///
/// All amounts are in the app's display currency. [remainingToday] can be
/// negative: that is the "over budget" state the UI shows in red.
class DailyBudgetSnapshot {
  const DailyBudgetSnapshot({
    required this.hasBudget,
    required this.budget,
    required this.monthExpense,
    required this.spentToday,
    required this.reservedUpcoming,
    required this.allowance,
    required this.remainingToday,
    required this.monthlyLeft,
    required this.rolledOver,
    required this.spentYesterday,
    required this.daysLeft,
    required this.daysInMonth,
    this.baseAllowance = 0,
    this.protectedSavings = 0,
    this.protectedEmergency = 0,
    this.safeToSpend,
    this.protectionApplied = false,
    this.recoveryCut = 0,
    this.recoveryApplied = false,
    this.unspentSoFar = 0,
    this.adjustmentReason,
    this.policy = AllowancePolicy.carryForward,
  });

  final bool hasBudget;
  final double budget;
  final double monthExpense;
  final double spentToday;

  /// Unpaid upcoming bills due this month (or overdue recurring bills).
  final double reservedUpcoming;

  /// Money available for today before today's spending.
  final double allowance;

  /// [allowance] minus [spentToday]; negative means over budget.
  final double remainingToday;

  /// Budget minus this month's expenses minus reserved upcoming bills.
  final double monthlyLeft;

  /// Unspent allowance carried in from earlier days (0 when the feature is off).
  final double rolledOver;

  final double spentYesterday;
  final int daysLeft;
  final int daysInMonth;

  /// The allowance before protection and recovery adjustments.
  final double baseAllowance;

  /// Monthly savings commitment kept out of spendable money.
  final double protectedSavings;

  /// User-defined emergency buffer kept out of spendable money.
  final double protectedEmergency;

  /// Confirmed balance minus bills, savings and the emergency buffer.
  ///
  /// Null when the ledger has no positive confirmed balance (for example a new
  /// install with only a budget and no income recorded), in which case the
  /// budget-based allowance is used without a protection cap.
  final double? safeToSpend;

  final bool protectionApplied;
  final double recoveryCut;
  final bool recoveryApplied;

  /// Unspent money from earlier days, whether or not it is carried forward.
  final double unspentSoFar;

  /// Short, human-readable explanation of why the allowance differs from the
  /// plain budget split. Amounts and details are shown by the UI.
  final String? adjustmentReason;

  final AllowancePolicy policy;

  double get spentRatio =>
      allowance <= 0 ? (spentToday > 0 ? 1.0 : 0.0) : spentToday / allowance;

  double get protectedTotal =>
      reservedUpcoming + protectedSavings + protectedEmergency;

  /// Budget money left after bills, savings commitments and the buffer.
  double get discretionaryLeft => math.max(
        0.0,
        monthlyLeft - protectedSavings - protectedEmergency,
      );

  bool get isAdjusted => protectionApplied || recoveryApplied;

  static const DailyBudgetSnapshot empty = DailyBudgetSnapshot(
    hasBudget: false,
    budget: 0,
    monthExpense: 0,
    spentToday: 0,
    reservedUpcoming: 0,
    allowance: 0,
    remainingToday: 0,
    monthlyLeft: 0,
    rolledOver: 0,
    spentYesterday: 0,
    daysLeft: 0,
    daysInMonth: 0,
  );
}

/// Pure daily-budget maths, kept out of widgets so it is easy to test.
class DailyBudget {
  const DailyBudget._();

  /// Builds a snapshot for [today] from a month's transactions.
  ///
  /// Carry forward on:
  ///   allowance = max(0, (budget - spentOutsideToday - reserved) / daysLeft)
  /// Fixed policies:
  ///   allowance = max(0, (budget - reserved) / daysInMonth)
  ///
  /// The result is then capped by confirmed safe-to-spend money (when enabled
  /// and a positive balance is known) and reduced by an active recovery plan.
  /// Each adjustment is recorded so the UI can explain it.
  static DailyBudgetSnapshot snapshot({
    required SettingsProvider settings,
    required List<Tx> transactions,
    required UpcomingProvider upcoming,
    double savingsCommitment = 0,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final month = DateTime(now.year, now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dayOfMonth = now.day.clamp(1, daysInMonth);
    final daysLeft = daysInMonth - dayOfMonth + 1;

    var monthExpense = 0.0;
    var spentToday = 0.0;
    var spentBeforeToday = 0.0;
    var spentYesterday = 0.0;
    var balance = 0.0;
    for (final t in transactions) {
      balance += t.balanceDelta;
      if (t.type != TxType.expense) continue;
      final amount = t.personalExpense;
      if (t.date.year != month.year || t.date.month != month.month) continue;
      monthExpense += amount;
      final day = t.date.day;
      if (day == dayOfMonth) {
        spentToday += amount;
      } else if (day < dayOfMonth) {
        spentBeforeToday += amount;
        if (day == dayOfMonth - 1) spentYesterday += amount;
      }
    }

    final reserved = upcoming.reservedForMonth(month);
    final budget = settings.monthlyBudget;
    final savings = math.max(0.0, savingsCommitment);
    final emergency = math.max(0.0, settings.emergencyBuffer);
    // A positive ledger balance is the only confirmed pool. Without one the
    // plan still works from the budget instead of pretending there is cash.
    final safeToSpend = balance > 0
        ? math.max(0.0, balance - reserved - savings - emergency)
        : null;

    if (budget <= 0) {
      return DailyBudgetSnapshot(
        hasBudget: false,
        budget: 0,
        monthExpense: monthExpense,
        spentToday: spentToday,
        reservedUpcoming: reserved,
        allowance: 0,
        remainingToday: 0,
        monthlyLeft: 0,
        rolledOver: 0,
        spentYesterday: spentYesterday,
        daysLeft: daysLeft,
        daysInMonth: daysInMonth,
        protectedSavings: savings,
        protectedEmergency: emergency,
        safeToSpend: safeToSpend,
        policy: settings.allowancePolicy,
        adjustmentReason: budget <= 0
            ? 'Set a monthly budget to turn confirmed money into a daily plan.'
            : null,
      );
    }

    final carry = settings.allowancePolicy == AllowancePolicy.carryForward;
    final baseDaily = math.max(0.0, budget - reserved) / daysInMonth;
    final unspentSoFar =
        math.max(0.0, baseDaily * (dayOfMonth - 1) - spentBeforeToday);
    final rolledOver = carry ? unspentSoFar : 0.0;

    // Everything recorded outside today — earlier days and any future-dated
    // entries this month — is already committed and must come out first.
    final spentOutsideToday = monthExpense - spentToday;
    final baseAllowance = carry
        ? math.max(0.0, (budget - spentOutsideToday - reserved) / daysLeft)
        : baseDaily;

    var allowance = baseAllowance;
    var protectionApplied = false;
    if (settings.moneyProtection && safeToSpend != null) {
      final protectionCap = safeToSpend / daysLeft;
      if (protectionCap < allowance) {
        allowance = protectionCap;
        protectionApplied = true;
      }
    }

    final cut = settings.recoveryCutOn(now);
    final recoveryApplied = cut > 0;
    if (recoveryApplied) {
      allowance = math.max(0.0, allowance - cut);
    }

    final reasons = <String>[];
    if (baseAllowance <= 0.005) {
      reasons.add(
        'No allowance is left after this month\'s spending and reserved bills.',
      );
    }
    if (recoveryApplied) {
      reasons.add('A recovery plan is reducing the daily target.');
    }
    if (protectionApplied) {
      reasons.add(
        'Capped by money left after bills, savings and your buffer.',
      );
    }
    if (reasons.isEmpty && !carry) {
      reasons.add(settings.allowancePolicy.description);
    }

    return DailyBudgetSnapshot(
      hasBudget: true,
      budget: budget,
      monthExpense: monthExpense,
      spentToday: spentToday,
      reservedUpcoming: reserved,
      allowance: allowance,
      remainingToday: allowance - spentToday,
      monthlyLeft: budget - monthExpense - reserved,
      rolledOver: rolledOver,
      spentYesterday: spentYesterday,
      daysLeft: daysLeft,
      daysInMonth: daysInMonth,
      baseAllowance: baseAllowance,
      protectedSavings: savings,
      protectedEmergency: emergency,
      safeToSpend: safeToSpend,
      protectionApplied: protectionApplied,
      recoveryCut: cut,
      recoveryApplied: recoveryApplied,
      unspentSoFar: unspentSoFar,
      adjustmentReason: reasons.isEmpty ? null : reasons.join(' '),
      policy: settings.allowancePolicy,
    );
  }

  /// Per-day report rows for [month].
  ///
  /// For the current month only days up to today are returned. Past months
  /// return every day so the report is a complete record.
  static List<DailyReportRow> reportRows({
    required SettingsProvider settings,
    required List<Tx> transactions,
    required UpcomingProvider upcoming,
    required DateTime month,
    DateTime? today,
    double? budgetOverride,
  }) {
    final now = today ?? DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrent = month.year == now.year && month.month == now.month;
    final lastDay = isCurrent ? now.day.clamp(1, daysInMonth) : daysInMonth;

    var spentBefore = 0.0;
    final rows = <DailyReportRow>[];
    // Bills that are still unpaid only affect the current (or a future)
    // month; a past month's report should show what was actually spent.
    final isPast = month.isBefore(DateTime(now.year, now.month));
    final reserved = isPast ? 0.0 : upcoming.reservedForMonth(month);
    final budget = budgetOverride ?? settings.monthlyBudget;
    final carry = settings.allowancePolicy == AllowancePolicy.carryForward;

    for (var day = 1; day <= lastDay; day++) {
      var spent = 0.0;
      var income = 0.0;
      for (final t in transactions) {
        if (t.date.year != month.year ||
            t.date.month != month.month ||
            t.date.day != day) {
          continue;
        }
        if (t.type.isExpense) {
          spent += t.personalExpense;
        } else if (!t.isSettlement) {
          income += t.amount;
        }
      }

      final daysLeft = daysInMonth - day + 1;
      double allowance;
      if (budget <= 0) {
        allowance = 0;
      } else if (carry) {
        allowance = math.max(0.0, (budget - spentBefore - reserved) / daysLeft);
      } else {
        allowance = math.max(0.0, (budget - reserved) / daysInMonth);
      }

      rows.add(DailyReportRow(
        date: DateTime(month.year, month.month, day),
        income: income,
        expense: spent,
        allowance: allowance,
        // Without a budget there is no allowance to compare against.
        remaining: budget <= 0 ? 0 : allowance - spent,
      ));
      spentBefore += spent;
    }
    return rows;
  }
}

class DailyReportRow {
  const DailyReportRow({
    required this.date,
    required this.income,
    required this.expense,
    required this.allowance,
    required this.remaining,
  });

  final DateTime date;
  final double income;
  final double expense;
  final double allowance;
  final double remaining;

  bool get isOver => remaining < 0;

  /// Days with any activity, income or expense.
  bool get hadSpending => expense > 0 || income > 0;

  /// Days with at least one expense. Used for "spent days" and over/under
  /// counts, which should ignore income-only days.
  bool get hadExpense => expense > 0;
}
