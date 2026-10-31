import 'dart:math' as math;

import '../models/upcoming_expense.dart';
import '../providers/upcoming_provider.dart';
import 'daily_budget.dart';
import 'money_plan.dart';

enum WhatIfKind { purchase, incomeDelay, billIncrease, weeklySaving }

extension WhatIfKindLabel on WhatIfKind {
  String get label => switch (this) {
        WhatIfKind.purchase => 'One-time purchase',
        WhatIfKind.incomeDelay => 'Income delayed',
        WhatIfKind.billIncrease => 'Bill increases',
        WhatIfKind.weeklySaving => 'Save every week',
      };
}

/// The projected state under one scenario. All figures are simulations.
class WhatIfResult {
  const WhatIfResult({
    required this.kind,
    required this.label,
    required this.todayLeft,
    required this.dailyAllowance,
    required this.monthLeft,
    required this.projectedBalance,
    required this.availableAfter,
    required this.billsShortfall,
    required this.goalDelayMonths,
    required this.notes,
  });

  final WhatIfKind? kind;
  final String label;
  final double todayLeft;
  final double dailyAllowance;
  final double monthLeft;
  final double projectedBalance;
  final double availableAfter;
  final double billsShortfall;
  final int goalDelayMonths;
  final List<String> notes;

  bool get isBaseline => kind == null;
}

enum Affordability { fitsToday, fitsMonth, tight, notCovered }

/// A deterministic purchase check. Never a payment or a guarantee.
class PurchaseVerdict {
  const PurchaseVerdict({
    required this.status,
    required this.title,
    required this.detail,
    required this.afterToday,
    required this.afterAvailable,
    required this.afterMonth,
    required this.dailyAfter,
    required this.waitDays,
    required this.waitPerDay,
  });

  final Affordability status;
  final String title;
  final String detail;
  final double afterToday;
  final double afterAvailable;
  final double afterMonth;
  final double dailyAfter;
  final int waitDays;
  final double waitPerDay;

  bool get isSafe =>
      status == Affordability.fitsToday || status == Affordability.fitsMonth;
}

/// Scenario maths for the What If screen and the purchase assistant.
class WhatIfEngine {
  const WhatIfEngine._();

  static WhatIfResult baseline({
    required DailyBudgetSnapshot snapshot,
    required MoneyPlan plan,
  }) {
    final days = math.max(1, snapshot.daysLeft);
    final projected = plan.balance -
        (snapshot.hasBudget ? math.max(0.0, snapshot.allowance) * days : 0);
    return WhatIfResult(
      kind: null,
      label: 'Current plan',
      todayLeft: snapshot.remainingToday,
      dailyAllowance: snapshot.allowance,
      monthLeft: snapshot.monthlyLeft,
      projectedBalance: projected,
      availableAfter: plan.availableToSpend,
      billsShortfall: 0,
      goalDelayMonths: 0,
      notes: const [],
    );
  }

  static WhatIfResult simulate({
    required WhatIfKind kind,
    required double amount,
    required int days,
    required DailyBudgetSnapshot snapshot,
    required MoneyPlan plan,
    required UpcomingProvider upcoming,
    required DateTime now,
  }) {
    final daysLeft = math.max(1, snapshot.daysLeft);
    final baseProjected = plan.balance -
        (snapshot.hasBudget ? math.max(0.0, snapshot.allowance) * daysLeft : 0);
    final value = math.max(0.0, amount);

    switch (kind) {
      case WhatIfKind.purchase:
        final availableAfter = plan.availableToSpend - value;
        final monthAfter = snapshot.monthlyLeft - value;
        final dailyAfter = _futureDaily(snapshot, monthAfter, daysLeft);
        return WhatIfResult(
          kind: kind,
          label: 'Spend ${_plain(value)} once',
          todayLeft: snapshot.remainingToday - value,
          dailyAllowance: dailyAfter,
          monthLeft: monthAfter,
          projectedBalance: baseProjected - value,
          availableAfter: availableAfter,
          billsShortfall: math.max(0.0, -availableAfter),
          goalDelayMonths: goalDelayMonths(value, plan.savingsCommitment),
          notes: [
            'This is a one-off purchase, not a recurring commitment.',
            if (availableAfter < 0)
              'It would use money reserved for bills, savings or your buffer.',
          ],
        );

      case WhatIfKind.billIncrease:
        final availableAfter = plan.availableToSpend - value;
        final monthAfter = snapshot.monthlyLeft - value;
        return WhatIfResult(
          kind: kind,
          label: 'Bill up ${_plain(value)}',
          todayLeft: snapshot.remainingToday,
          dailyAllowance: _futureDaily(snapshot, monthAfter, daysLeft),
          monthLeft: monthAfter,
          projectedBalance: baseProjected - value,
          availableAfter: availableAfter,
          billsShortfall: math.max(0.0, -availableAfter),
          goalDelayMonths: goalDelayMonths(value, plan.savingsCommitment),
          notes: [
            'The extra bill is protected before the daily allowance is split.',
            if (availableAfter < 0)
              'Confirmed money would not cover the increase plus protected buckets.',
          ],
        );

      case WhatIfKind.weeklySaving:
        final weeks = math.max(1, (daysLeft / 7).ceil());
        final total = value * weeks;
        final availableAfter = plan.availableToSpend - value;
        return WhatIfResult(
          kind: kind,
          label: 'Save ${_plain(value)} / week',
          todayLeft: snapshot.remainingToday,
          dailyAllowance: math.max(0.0, snapshot.allowance - value / 7),
          monthLeft: snapshot.monthlyLeft - total,
          projectedBalance: baseProjected - total,
          availableAfter: availableAfter,
          billsShortfall: math.max(0.0, -availableAfter),
          goalDelayMonths: 0,
          notes: [
            'Across the $weeks week${weeks == 1 ? '' : 's'} left this month '
                'that is ${_plain(total)} set aside.',
            'Savings goals are tracked separately from the ledger.',
          ],
        );

      case WhatIfKind.incomeDelay:
        final arrival =
            DateTime(now.year, now.month, now.day).add(Duration(days: days));
        final due = upcoming.all.where((item) {
          final date = DateTime(
            item.dueDate.year,
            item.dueDate.month,
            item.dueDate.day,
          );
          return !date.isBefore(DateTime(now.year, now.month, now.day)) &&
              !date.isAfter(arrival);
        }).toList();
        final dueTotal = due.fold(0.0, (sum, item) => sum + item.amount);
        final shortfall = math.max(0.0, dueTotal - plan.availableToSpend);
        return WhatIfResult(
          kind: kind,
          label: 'Income ${days}d late',
          todayLeft: snapshot.remainingToday,
          dailyAllowance: snapshot.allowance,
          monthLeft: snapshot.monthlyLeft,
          projectedBalance: baseProjected,
          availableAfter: plan.availableToSpend,
          billsShortfall: shortfall,
          goalDelayMonths: 0,
          notes: [
            'Expected money is not part of the balance until it actually arrives.',
            'Arrival moved to ${arrival.day}/${arrival.month}/${arrival.year}.',
            if (due.isEmpty)
              'No tracked bill is due before that date.'
            else
              '${due.length} bill${due.length == 1 ? '' : 's'} due before then: '
                  '${due.map((e) => e.title).take(3).join(', ')}.',
          ],
        );
    }
  }

  static PurchaseVerdict assessPurchase({
    required double price,
    required DailyBudgetSnapshot snapshot,
    required MoneyPlan plan,
  }) {
    final value = math.max(0.0, price);
    final daysLeft = math.max(1, snapshot.daysLeft);
    final afterToday = snapshot.remainingToday - value;
    final afterAvailable = plan.availableToSpend - value;
    final afterMonth = snapshot.monthlyLeft - value;
    final dailyAfter = _futureDaily(snapshot, afterMonth, daysLeft);

    final Affordability status;
    if (afterAvailable < -0.005) {
      status = Affordability.notCovered;
    } else if (afterToday >= -0.005) {
      status = Affordability.fitsToday;
    } else if (afterMonth >= -0.005) {
      status = Affordability.fitsMonth;
    } else {
      status = Affordability.tight;
    }

    final todayRoom = math.max(0.0, snapshot.remainingToday);
    var waitDays = 0;
    if (value > todayRoom && snapshot.allowance > 0) {
      waitDays = ((value - todayRoom) / snapshot.allowance).ceil();
    }
    final waitPerDay = waitDays > 0 ? value / waitDays : 0.0;

    final title = switch (status) {
      Affordability.fitsToday => 'Fits today',
      Affordability.fitsMonth => 'Fits this month, not today',
      Affordability.tight => 'Use money planned for later',
      Affordability.notCovered => 'Not covered by confirmed money',
    };
    final detail = switch (status) {
      Affordability.fitsToday =>
        'The purchase stays inside today\'s allowance and keeps protected '
            'money untouched.',
      Affordability.fitsMonth =>
        'It is above today\'s allowance. Buying it means less per day for the '
            'rest of the month.',
      Affordability.tight =>
        'Your confirmed balance can cover it, but the monthly plan would go '
            'over by ${_plain(-afterMonth)}.',
      Affordability.notCovered =>
        'After bills, savings commitments and your buffer, confirmed money '
            'would fall short by ${_plain(-afterAvailable)}.',
    };

    return PurchaseVerdict(
      status: status,
      title: title,
      detail: detail,
      afterToday: afterToday,
      afterAvailable: afterAvailable,
      afterMonth: afterMonth,
      dailyAfter: dailyAfter,
      waitDays: waitDays,
      waitPerDay: waitPerDay,
    );
  }

  static int goalDelayMonths(double amount, double monthlyCommitment) {
    if (amount <= 0 || monthlyCommitment <= 0) return 0;
    return (amount / monthlyCommitment).ceil();
  }

  static double _futureDaily(
    DailyBudgetSnapshot snapshot,
    double remainingBudget,
    int daysLeft,
  ) {
    if (!snapshot.hasBudget) return 0;
    final candidate = math.max(0.0, remainingBudget) / math.max(1, daysLeft);
    return math.min(snapshot.allowance, candidate);
  }

  static String _plain(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

/// Helper used by the income-delay screen without constructing a full result.
double billsDueBy(UpcomingProvider upcoming, DateTime start, DateTime end) {
  var total = 0.0;
  for (final UpcomingExpense item in upcoming.all) {
    final date =
        DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);
    if (!date.isBefore(start) && !date.isAfter(end)) total += item.amount;
  }
  return total;
}
