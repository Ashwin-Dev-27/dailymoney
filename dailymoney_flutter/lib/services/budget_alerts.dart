import '../providers/settings_provider.dart';
import '../utils/format.dart';
import 'daily_budget.dart';
import 'notification_service.dart';

/// Immediate budget notifications shared by manual entry and bill payments.
///
/// A notification is sent only on the save that crosses the 20%-left warning
/// line or uses up today's allowance, not on every later expense.
class BudgetAlerts {
  const BudgetAlerts._();

  static bool shouldNotify({
    required SettingsProvider settings,
    required DailyBudgetSnapshot before,
    required DailyBudgetSnapshot after,
    required bool isExpense,
  }) {
    if (!settings.budgetAlerts || !after.hasBudget || !isExpense) {
      return false;
    }
    // Only react when the new spend moved the remaining amount down.
    if (after.remainingToday >= before.remainingToday) return false;

    final warningLine = after.allowance * 0.2;
    final crossedWarning = before.remainingToday > warningLine &&
        after.remainingToday <= warningLine;
    final crossedZero = before.remainingToday > 0 && after.remainingToday <= 0;
    return crossedWarning || crossedZero;
  }

  static void maybeNotify({
    required SettingsProvider settings,
    required DailyBudgetSnapshot before,
    required DailyBudgetSnapshot after,
    required bool isExpense,
    required String currency,
  }) {
    if (!shouldNotify(
      settings: settings,
      before: before,
      after: after,
      isExpense: isExpense,
    )) {
      return;
    }

    final crossedZero = before.remainingToday > 0 && after.remainingToday <= 0;
    if (crossedZero) {
      NotificationService.showBudgetAlert(
        title: "Today's allowance is used up",
        body:
            'You are ${fmtMoney(-after.remainingToday, currency)} over today\'s '
            'budget. ${fmtMonthLeft(after.monthlyLeft, currency)}.',
      );
    } else {
      NotificationService.showBudgetAlert(
        title: 'Approaching your daily limit',
        body: '${fmtMoney(after.remainingToday, currency)} left of today\'s '
            'allowance. ${fmtMonthLeft(after.monthlyLeft, currency)}.',
      );
    }
  }
}
