import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailymoney/providers/settings_provider.dart';
import 'package:dailymoney/services/budget_alerts.dart';
import 'package:dailymoney/services/daily_budget.dart';
import 'package:dailymoney/services/storage_service.dart';

DailyBudgetSnapshot snapshot({required double remaining}) {
  return DailyBudgetSnapshot(
    hasBudget: true,
    budget: 3100,
    monthExpense: 0,
    spentToday: 100 - remaining,
    reservedUpcoming: 0,
    allowance: 100,
    remainingToday: remaining,
    monthlyLeft: remaining,
    rolledOver: 0,
    spentYesterday: 0,
    daysLeft: 10,
    daysInMonth: 31,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    settings = SettingsProvider(storage);
    await settings.load();
    // Budget alerts now start off until the user enables them.
    await settings.setBudgetAlerts(true);
  });

  group('BudgetAlerts.shouldNotify', () {
    test('fires when an expense crosses the 20% warning line', () {
      expect(
        BudgetAlerts.shouldNotify(
          settings: settings,
          before: snapshot(remaining: 30),
          after: snapshot(remaining: 15),
          isExpense: true,
        ),
        isTrue,
      );
    });

    test('fires when an expense uses up the allowance', () {
      expect(
        BudgetAlerts.shouldNotify(
          settings: settings,
          before: snapshot(remaining: 10),
          after: snapshot(remaining: -5),
          isExpense: true,
        ),
        isTrue,
      );
    });

    test('stays quiet while plenty of allowance is left', () {
      expect(
        BudgetAlerts.shouldNotify(
          settings: settings,
          before: snapshot(remaining: 80),
          after: snapshot(remaining: 60),
          isExpense: true,
        ),
        isFalse,
      );
    });

    test('does not repeat once the allowance is already spent', () {
      expect(
        BudgetAlerts.shouldNotify(
          settings: settings,
          before: snapshot(remaining: -5),
          after: snapshot(remaining: -20),
          isExpense: true,
        ),
        isFalse,
      );
    });

    test('ignores income and transactions that do not reduce the allowance',
        () {
      expect(
        BudgetAlerts.shouldNotify(
          settings: settings,
          before: snapshot(remaining: 30),
          after: snapshot(remaining: 15),
          isExpense: false,
        ),
        isFalse,
      );
      expect(
        BudgetAlerts.shouldNotify(
          settings: settings,
          before: snapshot(remaining: 15),
          after: snapshot(remaining: 15),
          isExpense: true,
        ),
        isFalse,
      );
    });

    test('respects the budget alert setting', () async {
      await settings.setBudgetAlerts(false);
      expect(
        BudgetAlerts.shouldNotify(
          settings: settings,
          before: snapshot(remaining: 30),
          after: snapshot(remaining: 15),
          isExpense: true,
        ),
        isFalse,
      );
    });

    test('does nothing without a monthly budget', () {
      const noBudget = DailyBudgetSnapshot(
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
        daysLeft: 10,
        daysInMonth: 31,
      );
      expect(
        BudgetAlerts.shouldNotify(
          settings: settings,
          before: noBudget,
          after: noBudget,
          isExpense: true,
        ),
        isFalse,
      );
    });
  });
}
