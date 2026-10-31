import 'dart:math' as math;

import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import 'daily_budget.dart';

/// The money map: confirmed balance split into protected buckets and money
/// that is genuinely available to spend.
///
/// Reservations are planning allocations, not bank transfers. The user's bank
/// balance is never changed by this calculation.
class MoneyPlan {
  const MoneyPlan({
    required this.snapshot,
    required this.balance,
    required this.billsReserved,
    required this.savingsCommitment,
    required this.emergencyBuffer,
    required this.safeToSpend,
    required this.availableToSpend,
    required this.monthlyDiscretionary,
    required this.dailySafeLimit,
    required this.hasConfirmedBalance,
  });

  final DailyBudgetSnapshot snapshot;
  final double balance;
  final double billsReserved;
  final double savingsCommitment;
  final double emergencyBuffer;
  final double safeToSpend;
  final double availableToSpend;
  final double monthlyDiscretionary;
  final double dailySafeLimit;
  final bool hasConfirmedBalance;

  double get protectedTotal =>
      billsReserved + savingsCommitment + emergencyBuffer;

  bool get protectionActive =>
      snapshot.protectionApplied && hasConfirmedBalance;

  static double savingsCommitmentFor(GoalsProvider goals, DateTime today) {
    var total = 0.0;
    for (final goal in goals.active) {
      if (goal.targetDate == null) continue;
      total += goal.monthlyNeeded(today);
    }
    return math.min(total, goals.totalRemaining);
  }

  /// Builds the allowance snapshot with savings commitments included.
  static DailyBudgetSnapshot snapshotFor({
    required SettingsProvider settings,
    required TransactionsProvider txs,
    required UpcomingProvider upcoming,
    required GoalsProvider goals,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    return DailyBudget.snapshot(
      settings: settings,
      transactions: txs.all,
      upcoming: upcoming,
      savingsCommitment: savingsCommitmentFor(goals, now),
      today: now,
    );
  }

  factory MoneyPlan.compute({
    required SettingsProvider settings,
    required TransactionsProvider txs,
    required UpcomingProvider upcoming,
    required GoalsProvider goals,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final savings = savingsCommitmentFor(goals, now);
    final snapshot = DailyBudget.snapshot(
      settings: settings,
      transactions: txs.all,
      upcoming: upcoming,
      savingsCommitment: savings,
      today: now,
    );
    final balance = txs.balance;
    final hasConfirmedBalance = balance > 0;
    final safe = snapshot.safeToSpend ?? 0;
    final available = hasConfirmedBalance
        ? safe
        : (snapshot.hasBudget ? math.max(0.0, snapshot.monthlyLeft) : 0.0);
    final days = math.max(1, snapshot.daysLeft);
    return MoneyPlan(
      snapshot: snapshot,
      balance: balance,
      billsReserved: snapshot.reservedUpcoming,
      savingsCommitment: savings,
      emergencyBuffer: snapshot.protectedEmergency,
      safeToSpend: safe,
      availableToSpend: available,
      monthlyDiscretionary: snapshot.hasBudget
          ? snapshot.discretionaryLeft
          : math.max(0.0, available),
      dailySafeLimit: safe / days,
      hasConfirmedBalance: hasConfirmedBalance,
    );
  }
}
